import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  ConnectedSocket,
  MessageBody,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger } from '@nestjs/common';
import Docker from 'dockerode';
import * as net from 'net';
import { SessionsService } from '../sessions/sessions.service';
import { LspUriTransformer } from './lsp-uri-transformer';
import { LspResponseBuffer } from './lsp-response-buffer';

interface ClientSession {
  sessionId: string;
  stream: net.Socket;
  workspaceRoot: string;
}

@WebSocketGateway({ cors: true, namespace: '/lsp' })
export class LanguageServerGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(LanguageServerGateway.name);
  private readonly docker: Docker;
  private readonly clientSessions = new Map<string, ClientSession>();
  private readonly LSP_CONTAINER_PORT = 9000;

  constructor(private readonly sessionsService: SessionsService) {
    this.docker = new Docker({ socketPath: '/var/run/docker.sock' });
  }

  handleConnection(client: Socket) {
    this.logger.log(`Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    const session = this.clientSessions.get(client.id);
    if (session?.stream) {
      session.stream.end();
    }
    this.clientSessions.delete(client.id);
    this.logger.log(`Client disconnected: ${client.id}`);
  }

  @SubscribeMessage('lsp-connect')
  async handleLSPConnect(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { sessionId: string },
  ) {
    this.logger.log(
      ['lsp-connect message', JSON.stringify(payload, null, 2)].join('\n'),
    );

    try {
      const { sessionId } = payload;

      const session = await this.sessionsService.getSession(sessionId);
      if (!session?.containerId) {
        client.emit('lsp-error', { error: 'Container not ready', code: 404 });
        return;
      }

      // Get workspace root for URI transformation
      const workspaceRoot = session.workspaceRoot || `/code-files/${sessionId}`;

      // Get container IP address from Docker network
      const container = this.docker.getContainer(session.containerId);
      const containerInfo = await container.inspect();
      const networks = containerInfo.NetworkSettings.Networks;
      const backendNetwork = networks['backend'];

      if (!backendNetwork?.IPAddress) {
        client.emit('lsp-error', {
          error: 'Container network not ready',
          code: 404,
        });
        return;
      }

      const containerIp = backendNetwork.IPAddress;

      // Create TCP connection to container
      const tcpSocket = new net.Socket();
      const lspResponseBuffer = new LspResponseBuffer();

      tcpSocket.connect(this.LSP_CONTAINER_PORT, containerIp, () => {
        this.logger.log(
          `TCP connected to ${containerIp}:${this.LSP_CONTAINER_PORT} for session ${sessionId}`,
        );

        this.clientSessions.set(client.id, {
          sessionId,
          stream: tcpSocket,
          workspaceRoot,
        });

        client.emit('lsp-connected', { success: true, sessionId });
      });

      tcpSocket.on('data', (chunk: Buffer) => {
        lspResponseBuffer.onData(chunk);
      });

      lspResponseBuffer.on('message', (rawMessage: string) => {
        this.logger.log(['[LSP Response]', rawMessage].join('\n'));

        const currentSession = this.clientSessions.get(client.id);
        const transformedMessage = currentSession
          ? LspUriTransformer.transformResponseMessage(
              rawMessage,
              currentSession.workspaceRoot,
            )
          : rawMessage;

        client.emit('lsp-message', { message: transformedMessage.toString() });
      });

      tcpSocket.on('error', (error) => {
        this.logger.error(`TCP error for session ${sessionId}`, error);
        client.emit('lsp-error', { error: 'Connection error', code: 500 });
      });

      tcpSocket.on('close', () => {
        this.logger.log(`TCP connection closed for session ${sessionId}`);
        client.emit('lsp-disconnected', { reason: 'Connection closed' });
        this.clientSessions.delete(client.id);
      });

      await this.sessionsService.updateLastActivity(sessionId);

      this.logger.log(
        `LSP connecting: client ${client.id}, session ${sessionId}`,
      );
    } catch (error) {
      this.logger.error('Failed to connect to LSP', error);
      client.emit('lsp-error', { error: 'Failed to connect', code: 500 });
    }
  }

  @SubscribeMessage('lsp-message')
  async handleLSPMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { message: string },
  ) {
    this.logger.log(['lsp-message message', payload.message].join('\n'));

    try {
      const session = this.clientSessions.get(client.id);
      if (!session?.stream) {
        client.emit('lsp-error', { error: 'Not connected', code: 400 });
        return;
      }

      // Transform client URIs to container URIs before sending
      const transformedMessage = LspUriTransformer.transformMessage(
        payload.message,
        session.workspaceRoot,
      );

      this.logger.log(['Transformed message', transformedMessage].join('\n'));

      session.stream.write(transformedMessage);
      await this.sessionsService.updateLastActivity(session.sessionId);
    } catch (error) {
      this.logger.error('Failed to send message to LSP', error);
      client.emit('lsp-error', { error: 'Failed to send message', code: 500 });
    }
  }
}

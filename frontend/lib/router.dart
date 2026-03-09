import 'package:go_router/go_router.dart';
import 'package:muglia/screens/dashboard/dashboard_screen.dart';
import 'package:muglia/screens/clientes/clientes_screen.dart';
import 'package:muglia/screens/clientes/cliente_form_screen.dart';
import 'package:muglia/screens/processos/processos_screen.dart';
import 'package:muglia/screens/processos/processo_detalhe_screen.dart';
import 'package:muglia/screens/prazos/prazos_screen.dart';
import 'package:muglia/screens/assistente/assistente_screen.dart';
import 'package:muglia/screens/chat/chat_screen.dart';
import 'package:muglia/screens/chat/conversa_screen.dart';
import 'package:muglia/screens/agentes/agentes_screen.dart';
import 'package:muglia/screens/agentes/agente_form_screen.dart';
import 'package:muglia/screens/documentos/documentos_screen.dart';
import 'package:muglia/screens/configuracoes/configuracoes_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/clientes',
      builder: (context, state) => const ClientesScreen(),
    ),
    GoRoute(
      path: '/clientes/novo',
      builder: (context, state) => const ClienteFormScreen(),
    ),
    GoRoute(
      path: '/clientes/:id',
      builder: (context, state) => ClienteFormScreen(
        clienteId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/processos',
      builder: (context, state) => const ProcessosScreen(),
    ),
    GoRoute(
      path: '/processos/:id',
      builder: (context, state) => ProcessoDetalheScreen(
        processoId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/prazos',
      builder: (context, state) => const PrazosScreen(),
    ),
    // Assistente unificado (nova tela principal)
    GoRoute(
      path: '/assistente',
      builder: (context, state) => const AssistenteScreen(),
    ),
    // Chat antigo (mantido para compatibilidade)
    GoRoute(
      path: '/chat',
      builder: (context, state) => const ChatScreen(),
    ),
    GoRoute(
      path: '/chat/:id',
      builder: (context, state) => ConversaScreen(
        conversaId: int.parse(state.pathParameters['id']!),
      ),
    ),
    // Agentes — rotas antigas mantidas + novas em /configuracoes/agentes
    GoRoute(
      path: '/agentes',
      builder: (context, state) => const AgentesScreen(),
    ),
    GoRoute(
      path: '/agentes/novo',
      builder: (context, state) => const AgenteFormScreen(),
    ),
    GoRoute(
      path: '/agentes/:id',
      builder: (context, state) => AgenteFormScreen(
        agenteId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/configuracoes/agentes',
      builder: (context, state) => const AgentesScreen(),
    ),
    GoRoute(
      path: '/configuracoes/agentes/novo',
      builder: (context, state) => const AgenteFormScreen(),
    ),
    GoRoute(
      path: '/configuracoes/agentes/:id',
      builder: (context, state) => AgenteFormScreen(
        agenteId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/documentos',
      builder: (context, state) => const DocumentosScreen(),
    ),
    GoRoute(
      path: '/configuracoes',
      builder: (context, state) => const ConfiguracoesScreen(),
    ),
  ],
);

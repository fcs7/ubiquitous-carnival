import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:muglia/theme/muglia_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.toString();

    return Drawer(
      child: Column(
        children: [
          // Header com logo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  MugliaTheme.primaryDark,
                  MugliaTheme.primary,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.balance,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Muglia',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gestao Juridica',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Menu items
          _DrawerItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            path: '/',
            isSelected: currentPath == '/',
          ),
          _DrawerItem(
            icon: Icons.people_rounded,
            label: 'Clientes',
            path: '/clientes',
            isSelected: currentPath.startsWith('/clientes'),
          ),
          _DrawerItem(
            icon: Icons.gavel_rounded,
            label: 'Processos',
            path: '/processos',
            isSelected: currentPath.startsWith('/processos'),
          ),
          _DrawerItem(
            icon: Icons.attach_money_rounded,
            label: 'Financeiro',
            path: '/financeiro',
            isSelected: currentPath.startsWith('/financeiro'),
          ),
          _DrawerItem(
            icon: Icons.schedule_rounded,
            label: 'Prazos',
            path: '/prazos',
            isSelected: currentPath.startsWith('/prazos'),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Divider(),
          ),

          _DrawerItem(
            icon: Icons.chat_rounded,
            label: 'Chat Juridico',
            path: '/chat',
            isSelected: currentPath.startsWith('/chat'),
            accentColor: MugliaTheme.accent,
          ),
          _DrawerItem(
            icon: Icons.folder_rounded,
            label: 'Documentos',
            path: '/documentos',
            isSelected: currentPath.startsWith('/documentos'),
          ),

          const Spacer(),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(),
          ),

          _DrawerItem(
            icon: Icons.settings_rounded,
            label: 'Configuracoes',
            path: '/configuracoes',
            isSelected: currentPath.startsWith('/configuracoes'),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String path;
  final bool isSelected;
  final Color? accentColor;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.isSelected,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? (accentColor ?? MugliaTheme.primary)
        : MugliaTheme.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected
            ? (accentColor ?? MugliaTheme.primary).withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pop(context);
            context.go(path);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? MugliaTheme.textPrimary : color,
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accentColor ?? MugliaTheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

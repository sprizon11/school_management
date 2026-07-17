import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'admin_screen_header.dart';

class AdminSubPageScaffold extends StatelessWidget {
  const AdminSubPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
    this.floatingAction,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminScreenBody.pageBackground,
      floatingActionButton: floatingAction,
      // Same header as the main tabs, plus a back button.
      body: Column(
        children: [
          AdminScreenHeader(
            title: title,
            subtitle: subtitle,
            titleSize: 24,
            leading: AdminHeaderIconButton(
              icon: Icons.arrow_back_rounded,
              plain: true,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            actions: actions ?? const [],
          ),
          Expanded(child: AdminScreenBody(child: child)),
        ],
      ),
    );
  }
}

class AdminPremiumCard extends StatelessWidget {
  const AdminPremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF20345B).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AdminFormField extends StatelessWidget {
  const AdminFormField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.obscureText = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null
                ? Icon(icon, color: AppColors.primary, size: 20)
                : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AdminPrimaryButton extends StatelessWidget {
  const AdminPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class AdminStatTile extends StatelessWidget {
  const AdminStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AdminPremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSectionTitle extends StatelessWidget {
  const AdminSectionTitle(this.title, {super.key, this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF131B2E),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminListTilePremium extends StatelessWidget {
  const AdminListTilePremium({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leadingIcon,
    this.leadingColor,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final IconData? leadingIcon;
  final Color? leadingColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AdminPremiumCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (leadingIcon != null)
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: (leadingColor ?? AppColors.primary).withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  leadingIcon,
                  color: leadingColor ?? AppColors.primary,
                  size: 20,
                ),
              ),
            if (leadingIcon != null) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

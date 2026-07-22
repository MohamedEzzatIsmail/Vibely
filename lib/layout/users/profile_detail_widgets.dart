part of 'users_screen.dart';

class _ProfileDetails extends StatelessWidget {
  final dynamic model;
  // isOwnProfile = true  → show all info regardless of hide flags
  // isOwnProfile = false → respect hideEmail / hidePhone
  final bool isOwnProfile;
  const _ProfileDetails({required this.model, this.isOwnProfile = true});

  @override
  Widget build(BuildContext context) {
    final email     = model.email ?? '';
    final phone     = model.phone ?? '';
    final hideEmail = isOwnProfile ? false : (model.hideEmail ?? false);
    final hidePhone = isOwnProfile ? false : (model.hidePhone ?? false);

    final showEmail = email.isNotEmpty && !hideEmail;
    final showPhone = phone.isNotEmpty && !hidePhone;

    if (!showEmail && !showPhone) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.of(context).accountInfoTitle, style: TextStyle(
              color: AppColors.of(context).text, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (showEmail)
            _DetailRow(icon: Icons.email_outlined, label: AppStrings.of(context).email, value: email),
          if (showPhone) ...[
            const SizedBox(height: 8),
            _DetailRow(icon: Icons.phone_outlined, label: AppStrings.of(context).phone, value: phone),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFe5c687), size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(color: AppColors.of(context).text, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  OPTION TILE (used in image picker sheet)
// ══════════════════════════════════════════════════════════════════════════════
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OptionTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFe5c687).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFFe5c687), size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              color: AppColors.of(context).text, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      onTap: onTap,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  EditProfileButton  –  kept for any other screens that import it
// ══════════════════════════════════════════════════════════════════════════════
class EditProfileButton extends StatelessWidget {
  final VoidCallback onTap;
  const EditProfileButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.edit_rounded,
            size: 18, color: Color(0xFFe5c687)),
        label: Text(
          AppStrings.of(context).editProfileTitle,
          style: const TextStyle(
            color: Color(0xFFe5c687),
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFe5c687), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

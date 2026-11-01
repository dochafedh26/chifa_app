import 'package:chifa/app/cubits/auth_cubit.dart';
import 'package:chifa/app/cubits/doctor_working_hours_cubit.dart';
import 'package:chifa/app/screens/appointments/working_hours_dialog.dart';
import 'package:chifa/app/screens/settings/user_form_dialog.dart';
import 'package:chifa/services/db/models/employee.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class UserProfileDialog extends StatefulWidget {
  final Employee user;

  const UserProfileDialog({super.key, required this.user});

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  @override
  void initState() {
    super.initState();
    // Load working hours once on open
    context.read<DoctorWorkingHoursCubit>().loadWorkingHours(
      widget.user.employeeId!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with Avatar
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      widget.user.firstName[0].toUpperCase() +
                          widget.user.lastName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.user.fullName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.user.role.name,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // User details
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildInfoRow(
                    context,
                    Icons.email_outlined,
                    'Email',
                    widget.user.email,
                  ),
                  if (widget.user.phone != null && widget.user.phone!.isNotEmpty)
                    _buildInfoRow(
                      context,
                      Icons.phone_outlined,
                      'Phone',
                      widget.user.phone!,
                    ),
                  if (widget.user.specialization != null &&
                      widget.user.specialization!.isNotEmpty)
                    _buildInfoRow(
                      context,
                      Icons.work_outline,
                      'Specialization',
                      widget.user.specialization!,
                    ),
                  _buildInfoRow(
                    context,
                    Icons.security_outlined,
                    'Access Level',
                    widget.user.accessLevel.name,
                  ),
                ],
              ),
            ),

            // Working Hours Section (Doctors Only)
            if (widget.user.role == EmployeeRole.doctor) ...[
              const Divider(height: 1),
              _buildWorkingHoursSection(context),
            ],

            // Actions
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      context.read<AuthCubit>().logout();
                      context.go('/login');
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // Close profile dialog
                          _showEditProfileDialog(context);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit Profile'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => UserFormDialog(employee: widget.user),
    );
  }

  Widget _buildWorkingHoursSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Working Schedule',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: Colors.grey.shade700),
              ),
              TextButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) =>
                      WorkingHoursDialog(doctorId: widget.user.employeeId!),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Slot', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BlocBuilder<DoctorWorkingHoursCubit, DoctorWorkingHoursState>(
            builder: (context, state) {
              if (state is DoctorWorkingHoursLoading) {
                return const Center(child: LinearProgressIndicator());
              } else if (state is DoctorWorkingHoursLoaded) {
                if (state.slots.isEmpty) {
                  return Text(
                    'No working hours scheduled.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  );
                }
                // Show last 3 slots
                final displaySlots = state.slots.take(3).toList();
                return Column(
                  children: displaySlots.map((slot) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMM dd').format(slot.workingDate),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${slot.startTime.substring(0, 5)} - ${slot.endTime.substring(0, 5)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

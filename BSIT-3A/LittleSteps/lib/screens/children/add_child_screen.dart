import 'package:flutter/material.dart';

import '../../models/child_validators.dart';
import '../../theme/app_tokens.dart';

/// Form for adding a child profile (issue #3).
///
/// Validates the nickname on the device first. The server still checks
/// every field when the profile is saved.
class AddChildScreen extends StatefulWidget {
  /// Creates the add child profile screen.
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

/// State for [AddChildScreen].
class _AddChildScreenState extends State<AddChildScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();

  /// Disposes the nickname controller when the screen is removed from the tree.
  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  /// Checks every field and shows its error message under it.
  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    // Saving through ChildrenService is added in Step 3.
  }

  /// Builds the screen with a form for adding a child profile.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add child profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.space16),
          children: [
            TextFormField(
              controller: _nicknameController,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nickname'),
              validator: validateNickname,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.space16),
            SizedBox(
              height: AppSizes.touchTarget,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

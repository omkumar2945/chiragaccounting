import 'package:flutter/material.dart';

class PaymentSection extends StatelessWidget {
  final TextEditingController notesController;
  final TextEditingController paymentTermsController;

  final VoidCallback onSaveDraft;
  final VoidCallback onSaveInvoice;
  final VoidCallback onPreview;
  final VoidCallback onUploadAttachment;

  const PaymentSection({
    super.key,
    required this.notesController,
    required this.paymentTermsController,
    required this.onSaveDraft,
    required this.onSaveInvoice,
    required this.onPreview,
    required this.onUploadAttachment,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Payment & Notes",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            TextFormField(
              controller: paymentTermsController,
              decoration: const InputDecoration(
                labelText: "Payment Terms",
                prefixIcon: Icon(Icons.payment),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Notes",
                prefixIcon: Icon(Icons.note_alt),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onUploadAttachment,
                icon: const Icon(Icons.attach_file),
                label: const Text("Upload Invoice Attachment"),
              ),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSaveDraft,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text("Save Draft"),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onSaveInvoice,
                    icon: const Icon(Icons.check_circle),
                    label: const Text("Save Invoice"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPreview,
                icon: const Icon(Icons.visibility),
                label: const Text("Preview Invoice"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boilerplate/core/widgets/toast_message.dart';

/// Shared comment dialog used across manager review screens
class ManagerCommentDialog extends StatefulWidget {
  const ManagerCommentDialog({
    super.key,
    required this.action,
    this.entityLabel = 'Items',
    this.description,
    this.hintText,
    this.requireComment = true,
    this.missingCommentMessage,
  });

  final String action;
  final String entityLabel;
  final String? description;
  final String? hintText;
  final bool requireComment;
  final String? missingCommentMessage;

  static Future<String?> show(
    BuildContext context, {
    required String action,
    String entityLabel = 'Items',
    String? description,
    String? hintText,
    bool requireComment = true,
    String? missingCommentMessage,
  }) {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      useRootNavigator: true,
      builder: (ctx) => ManagerCommentDialog(
        action: action,
        entityLabel: entityLabel,
        description: description,
        hintText: hintText,
        requireComment: requireComment,
        missingCommentMessage: missingCommentMessage,
      ),
    );
  }

  @override
  State<ManagerCommentDialog> createState() => _ManagerCommentDialogState();
}

class _ManagerCommentDialogState extends State<ManagerCommentDialog> {
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final descriptionText = widget.description ??
        'Please provide a comment for ${widget.action} action${widget.requireComment ? '' : ' (optional)'}:';
    final titleFont = isTablet ? 18.0 : 16.0;
    final bodyFont = isTablet ? 14.0 : 13.0;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isTablet ? 20 : 18),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isTablet ? 500 : double.infinity,
        ),
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: isTablet ? 40 : 36,
                  height: isTablet ? 40 : 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4db1b3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.comment_outlined,
                    color: Color(0xFF4db1b3),
                    size: 20,
                  ),
                ),
                SizedBox(width: isTablet ? 14 : 12),
                Expanded(
                  child: Text(
                    '${widget.action} ${widget.entityLabel}',
                    style: GoogleFonts.inter(
                      fontSize: titleFont,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[900],
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (Navigator.of(context, rootNavigator: true).canPop()) {
                      Navigator.of(context, rootNavigator: true).pop();
                    }
                  },
                  icon: Icon(Icons.close, color: Colors.grey[600], size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            SizedBox(height: isTablet ? 20 : 16),
            Text(
              descriptionText,
              style: GoogleFonts.inter(
                fontSize: bodyFont,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: isTablet ? 16 : 14),
            TextField(
              controller: _commentController,
              maxLines: 4,
              style: GoogleFonts.inter(
                fontSize: bodyFont,
                color: Colors.grey[900],
              ),
              decoration: InputDecoration(
                hintText: widget.hintText ?? 'Enter your comment...',
                hintStyle: GoogleFonts.inter(
                  fontSize: bodyFont,
                  color: Colors.grey[400],
                ),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4db1b3), width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 16 : 14,
                  vertical: isTablet ? 16 : 14,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            SizedBox(height: isTablet ? 24 : 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    if (Navigator.of(context, rootNavigator: true).canPop()) {
                      Navigator.of(context, rootNavigator: true).pop();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20 : 18,
                      vertical: isTablet ? 12 : 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontSize: bodyFont,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                SizedBox(width: isTablet ? 12 : 10),
                FilledButton(
                  onPressed: () {
                    final comment = _commentController.text.trim();
                    if (widget.requireComment && comment.isEmpty) {
                      ToastMessage.show(
                        context,
                        message: widget.missingCommentMessage ?? 'Please enter a comment to continue',
                        type: ToastType.warning,
                        useRootNavigator: true,
                        duration: const Duration(seconds: 2),
                      );
                      return;
                    }
                    if (Navigator.of(context, rootNavigator: true).canPop()) {
                      Navigator.of(context, rootNavigator: true).pop(comment);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4db1b3),
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20 : 18,
                      vertical: isTablet ? 12 : 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    widget.action,
                    style: GoogleFonts.inter(
                      fontSize: bodyFont,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


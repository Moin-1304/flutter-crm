import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boilerplate/data/network/apis/expense/expense_api_models.dart';
import 'package:boilerplate/data/network/constants/endpoints.dart';
import 'package:boilerplate/core/data/network/dio/dio_client.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/core/widgets/toast_message.dart';

/// Full-screen attachment viewer: images open in-app with zoom, others open externally.
class AttachmentViewerScreen extends StatelessWidget {
  const AttachmentViewerScreen({super.key, required this.attachments});

  final List<ExpenseAttachment> attachments;

  static bool isImageType(String type) {
    final t = type.toLowerCase();
    return t.contains('image') ||
        t.contains('jpg') ||
        t.contains('jpeg') ||
        t.contains('png') ||
        t.contains('gif') ||
        t.contains('webp');
  }

  /// Open a single attachment: images in full-screen, others (docx, pdf, etc.) download then open in system app.
  static Future<void> openAttachment(
      BuildContext context, ExpenseAttachment att) async {
    final path = att.filePath.trim();
    final name = att.fileName.trim();
    if (path.isEmpty || name.isEmpty) {
      if (context.mounted) {
        ToastMessage.show(
          context,
          message: 'Invalid attachment: missing file path or name',
          type: ToastType.error,
        );
      }
      return;
    }
    String url;
    try {
      url = Endpoints.fileDownload(path, name);
    } catch (e) {
      if (context.mounted) {
        ToastMessage.show(
          context,
          message: 'Invalid attachment: ${e.toString()}',
          type: ToastType.error,
        );
      }
      return;
    }
    final isImage = isImageType(att.fileType);
    if (isImage) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _ImageAttachmentViewer(
            url: url,
            title: att.fileName,
          ),
        ),
      );
    } else {
      // For docx, pdf, etc.: download with auth then open in system app; fallback to browser.
      if (!context.mounted) return;
      ToastMessage.show(
        context,
        message: 'Opening ${att.fileName}...',
        type: ToastType.info,
      );
      bool opened = false;
      try {
        if (getIt.isRegistered<DioClient>()) {
          final dio = getIt<DioClient>().dio;
          final response = await dio.get<List<int>>(
            url,
            options: Options(responseType: ResponseType.bytes),
          );
          final data = response.data;
          if (data != null && data.isNotEmpty) {
            final tempDir = await getTemporaryDirectory();
            final safeName = name.replaceAll(RegExp(r'[^\w\.\-]'), '_');
            final file = File('${tempDir.path}/$safeName');
            await file.writeAsBytes(data);
            final result = await OpenFilex.open(file.path);
            if (result.type == ResultType.done) {
              opened = true;
            } else if (context.mounted) {
              if (result.type == ResultType.noAppToOpen) {
                ToastMessage.show(
                  context,
                  message:
                      'No app to open this file. Opening in browser instead.',
                  type: ToastType.info,
                );
              }
            }
          }
        }
      } catch (_) {
        // Download or open failed; try browser fallback below
      }
      if (!opened && context.mounted) {
        final uri = Uri.parse(url);
        try {
          if (await canLaunchUrl(uri)) {
            final launched =
                await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (launched) {
              ToastMessage.show(
                context,
                message:
                    'Opened in browser. You can download or open the file there.',
                type: ToastType.info,
              );
              return;
            }
          }
        } catch (_) {}
        ToastMessage.show(
          context,
          message:
              'Could not open attachment. Try opening the link in a browser.',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Attachments'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: attachments.isEmpty
          ? const Center(
              child: Text(
                'No attachments',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: attachments.length,
              itemBuilder: (context, index) {
                final att = attachments[index];
                final isImage = isImageType(att.fileType);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: Colors.grey[900],
                  child: ListTile(
                    leading: Icon(
                      isImage ? Icons.image : Icons.attach_file,
                      color: const Color(0xFF4db1b3),
                      size: 28,
                    ),
                    title: Text(
                      att.fileName,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.open_in_full,
                        color: Color(0xFF4db1b3)),
                    onTap: () => openAttachment(context, att),
                  ),
                );
              },
            ),
    );
  }
}

/// Loads image via app Dio (auth + SSL) and displays with Image.memory.
class _ImageAttachmentViewer extends StatefulWidget {
  final String url;
  final String title;

  const _ImageAttachmentViewer({required this.url, required this.title});

  @override
  State<_ImageAttachmentViewer> createState() => _ImageAttachmentViewerState();
}

class _ImageAttachmentViewerState extends State<_ImageAttachmentViewer> {
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (!getIt.isRegistered<DioClient>()) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Network not available';
        });
      }
      return;
    }
    try {
      final dio = getIt<DioClient>().dio;
      final response = await dio.get<List<int>>(
        widget.url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data != null && data.isNotEmpty && mounted) {
        setState(() {
          _bytes = Uint8List.fromList(data);
          _loading = false;
          _error = null;
        });
      } else if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Empty response';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load image: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator(color: Color(0xFF4db1b3))
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  )
                : _bytes != null && _bytes!.isNotEmpty
                    ? InteractiveViewer(
                        child: Image.memory(
                          _bytes!,
                          fit: BoxFit.contain,
                        ),
                      )
                    : const Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white70),
                      ),
      ),
    );
  }
}

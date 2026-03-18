import 'package:flutter/material.dart';

class InputField extends StatefulWidget {
  final Function(String) onSend;
  final bool isLoading;

  const InputField({super.key, required this.onSend, required this.isLoading});

  @override
  State<InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !widget.isLoading) {
      widget.onSend(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSendEnabled = _hasText && !widget.isLoading;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !widget.isLoading,
                decoration: InputDecoration(
                  hintText: 'Ask about safety...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: const BorderSide(color: Color(0xFF101D68), width: 2.0),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  filled: true,
                  fillColor: widget.isLoading ? Colors.grey[100] : Colors.white,
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: isSendEnabled ? (_) => _handleSend() : null,
              ),
            ),
            const SizedBox(width: 8.0),
            GestureDetector(
              onTap: isSendEnabled ? _handleSend : null,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isSendEnabled
                        ? [const Color(0xFF3950C6), const Color(0xFF101D68)]
                        : [Colors.grey[300]!, Colors.grey[400]!],
                  ),
                ),
                child: const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

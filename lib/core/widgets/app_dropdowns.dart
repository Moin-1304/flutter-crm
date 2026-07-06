import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:google_fonts/google_fonts.dart';

class SingleSelectDropdown extends StatefulWidget {
  const SingleSelectDropdown({super.key, required this.options, required this.value, required this.onChanged, this.hintText});
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? hintText;

  @override
  State<SingleSelectDropdown> createState() => _SingleSelectDropdownState();
}

class _SingleSelectDropdownState extends State<SingleSelectDropdown> {
  final LayerLink _link = LayerLink();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _entry;
  String? _value;

  @override
  void deactivate() {
    // Ensure overlay is removed before this widget leaves the tree
    _removeOverlay();
    super.deactivate();
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _value = widget.value;
    // Prevent the field from requesting focus to avoid keyboard
    _focusNode.canRequestFocus = false;
  }

  @override
  void didUpdateWidget(covariant SingleSelectDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _value) {
      _value = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: _value ?? '');
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: _toggleOverlay,
        behavior: HitTestBehavior.opaque,
        child: AbsorbPointer(
          child: TextFormField(
            readOnly: true,
            controller: _value == null ? null : controller,
            focusNode: _focusNode,
            enableInteractiveSelection: false,
            decoration: InputDecoration(
              hintText: _value == null ? (widget.hintText ?? 'Select') : null,
              suffixIcon: const Icon(Icons.expand_more),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleOverlay() {
    // Dismiss keyboard and unfocus everything
    _focusNode.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    
    if (_entry == null) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    // Dismiss keyboard and unfocus everything
    _focusNode.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Size size = box.size;
    _entry = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(onTap: _removeOverlay, behavior: HitTestBehavior.translucent),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 8),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: size.width,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 18, offset: const Offset(0, 6)),
                    ],
                    border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(.4)),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: (widget.options.length * 52.0 + 24)
                          .clamp(120.0, 320.0),
                    ),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      itemCount: widget.options.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final opt = widget.options[i];
                        final selected = opt == _value;
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            _value = opt;
                            widget.onChanged(opt);
                            setState(() {});
                            _removeOverlay();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(.6), width: 1.4),
                                    color: selected ? theme.colorScheme.primary : Colors.transparent,
                                  ),
                                  child: selected
                                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    opt,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_entry!);
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }
}

class MultiSelectDropdown extends StatefulWidget {
  const MultiSelectDropdown({super.key, required this.options, required this.selectedValues, required this.onChanged, this.hintText});
  final List<String> options;
  final Set<String> selectedValues;
  final ValueChanged<Set<String>> onChanged;
  final String? hintText;

  @override
  State<MultiSelectDropdown> createState() => _MultiSelectDropdownState();
}

class _MultiSelectDropdownState extends State<MultiSelectDropdown> {
  final LayerLink _link = LayerLink();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _entry;
  Set<String> _selected = <String>{};

  @override
  void deactivate() {
    // Ensure overlay is removed before this widget leaves the tree
    _removeOverlay();
    super.deactivate();
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selected = {...widget.selectedValues};
    // Prevent the field from requesting focus to avoid keyboard
    _focusNode.canRequestFocus = false;
  }

  @override
  void didUpdateWidget(covariant MultiSelectDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!setEquals(_selected, widget.selectedValues)) {
      _selected = {...widget.selectedValues};
    }
  }

  @override
  Widget build(BuildContext context) {
    final String display = _summary(_selected);
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: _toggleOverlay,
        behavior: HitTestBehavior.opaque,
        child: AbsorbPointer(
          child: TextFormField(
            readOnly: true,
            focusNode: _focusNode,
            enableInteractiveSelection: false,
            decoration: InputDecoration(
              hintText: display.isEmpty ? (widget.hintText ?? 'Select') : null,
              suffixIcon: const Icon(Icons.expand_more),
            ),
            controller: display.isEmpty
                ? null
                : (TextEditingController(text: display)..selection = TextSelection.collapsed(offset: display.length)),
          ),
        ),
      ),
    );
  }

  void _toggleOverlay() {
    // Dismiss keyboard and unfocus everything
    _focusNode.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    
    if (_entry == null) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    // Dismiss keyboard and unfocus everything
    _focusNode.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Size size = box.size;
    _entry = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(onTap: _removeOverlay, behavior: HitTestBehavior.translucent),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: Offset(0, size.height - 1),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: size.width,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.zero,
                      topRight: Radius.zero,
                      bottomLeft: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 18, offset: const Offset(0, 6)),
                    ],
                    border: Border(
                      left: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(.4)),
                      right: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(.4)),
                      bottom: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(.4)),
                    ),
                  ),
                  child: Theme(
                    data: theme.copyWith(
                      checkboxTheme: CheckboxThemeData(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(.6), width: 1.4),
                        fillColor: WidgetStateProperty.resolveWith((states) => theme.colorScheme.primary),
                      ),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: widget.options.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final opt = widget.options[i];
                          final selected = _selected.contains(opt);
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _toggle(opt),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(.6), width: 1.6),
                                      color: selected ? theme.colorScheme.primary : Colors.transparent,
                                    ),
                                    child: selected
                                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                  child: Text(
                                    opt,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_entry!);
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  void _toggle(String opt) {
    if (_selected.contains(opt)) {
      _selected.remove(opt);
    } else {
      _selected.add(opt);
    }
    widget.onChanged({..._selected});
    setState(() {});
    _entry?.markNeedsBuild();
  }

  String _summary(Set<String> values) {
    if (values.isEmpty) return '';
    if (values.length <= 2) return values.join(', ');
    final firstTwo = values.take(2).join(', ');
    return '$firstTwo +${values.length - 2}';
  }
}

class SearchableDropdown extends StatefulWidget {
  const SearchableDropdown({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.hintText,
    this.searchHintText,
    this.hasError = false,
    this.maxOverlayHeight,
  });
  
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? hintText;
  final String? searchHintText;
  final bool hasError;
  /// Max height for the dropdown panel; defaults to ~55% of screen height.
  final double? maxOverlayHeight;

  @override
  State<SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
  final LayerLink _link = LayerLink();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _displayController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _displayFocusNode = FocusNode();
  OverlayEntry? _entry;
  String? _value;
  String? _previousWidgetValue; // Track previous widget value to detect actual changes
  bool _isUserSelecting = false; // Flag to prevent value reset during user selection
  List<String> _filteredOptions = [];

  @override
  void deactivate() {
    // Ensure overlay is removed before this widget leaves the tree
    _removeOverlay();
    super.deactivate();
  }

  @override
  void dispose() {
    _removeOverlay();
    _searchController.dispose();
    _displayController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _displayFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _value = widget.value;
    _previousWidgetValue = widget.value;
    _filteredOptions = widget.options;
    _updateDisplayText();
    // Prevent the display field from requesting focus to avoid keyboard
    _displayFocusNode.canRequestFocus = false;
    // Ensure search field starts unfocused
    _searchFocusNode.unfocus();
  }

  @override
  void didUpdateWidget(covariant SearchableDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Always sync _value with widget.value when widget.value changes
    // This ensures the dropdown displays the correct value from the parent
    // But only if we're not in the middle of a user selection
    if (!_isUserSelecting && widget.value != oldWidget.value) {
      print('🔵 SearchableDropdown didUpdateWidget: widget.value changed from "${oldWidget.value}" to "${widget.value}"');
      _previousWidgetValue = widget.value;
      _value = widget.value;
      _updateDisplayText();
    } else if (_isUserSelecting && widget.value == _value) {
      // User selection completed - parent has updated to match our selection
      print('🔵 SearchableDropdown didUpdateWidget: User selection confirmed, widget.value now matches _value: "${widget.value}"');
      _isUserSelecting = false;
      _previousWidgetValue = widget.value;
    }
    if (widget.options != oldWidget.options) {
      _filteredOptions = widget.options;
      // Update filtered options without rebuilding overlay during build phase
      if (_searchController.text.isNotEmpty) {
        _filteredOptions = widget.options
            .where((option) => option.toLowerCase().contains(_searchController.text.toLowerCase()))
            .toList();
      }
      // Schedule overlay rebuild after current frame
      if (_entry != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_entry != null && mounted) {
            _entry!.markNeedsBuild();
          }
        });
      }
    }
  }

  void _updateDisplayText() {
    final String display = _value ?? '';
    if (_displayController.text != display) {
      _displayController.text = display;
      _displayController.selection = TextSelection.collapsed(offset: display.length);
    }
  }

  void _filterOptions(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredOptions = widget.options;
      } else {
        _filteredOptions = widget.options
            .where((option) => option.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
    // Rebuild the overlay to show updated filtered options
    // Use post-frame callback to avoid calling during build
    if (_entry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_entry != null && mounted) {
          _entry!.markNeedsBuild();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only sync value in build if widget.value has changed from previous widget.value
    // AND we're not in the middle of a user selection
    // This prevents resetting the value when user selects a new option
    if (!_isUserSelecting && widget.value != _previousWidgetValue && widget.value != null) {
      print('🔵 SearchableDropdown build: widget.value changed from "$_previousWidgetValue" to "${widget.value}", syncing _value');
      _value = widget.value;
      _previousWidgetValue = widget.value;
      _updateDisplayText();
    }
    final Color borderColor = widget.hasError ? Colors.red.shade400 : Colors.grey.shade300;
    final Color focusedBorderColor = widget.hasError ? Colors.red.shade400 : Colors.blue.shade200;
    
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: _toggleOverlay,
        behavior: HitTestBehavior.opaque,
        child: AbsorbPointer(
          child: TextFormField(
            readOnly: true,
            controller: _displayController,
            focusNode: _displayFocusNode,
            enableInteractiveSelection: false,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: _value == null || _value!.isEmpty ? (widget.hintText ?? 'Select') : null,
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey[500],
              ),
              suffixIcon: const Icon(Icons.expand_more),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor, width: widget.hasError ? 1.4 : 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor, width: widget.hasError ? 1.4 : 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: focusedBorderColor, width: widget.hasError ? 2.2 : 2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleOverlay() {
    // Dismiss keyboard and unfocus everything before toggling overlay
    _displayFocusNode.unfocus();
    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    
    if (_entry == null) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    // Dismiss keyboard and unfocus everything before showing overlay
    _displayFocusNode.unfocus();
    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Size size = box.size;
    
    _searchController.clear();
    _filteredOptions = widget.options;
    
    const double searchSectionHeight = 68.0;
    const double optionRowHeight = 48.0;
    const double listBottomPadding = 12.0;

    final Offset currentPosition = box.localToGlobal(Offset.zero);
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double screenHeight = mediaQuery.size.height;
    final double spaceBelow = screenHeight - currentPosition.dy - size.height;
    final double spaceAbove = currentPosition.dy;

    final double maxPanelHeight = widget.maxOverlayHeight ??
        (screenHeight * 0.55).clamp(280.0, 520.0);

    final double availableBelow = (spaceBelow - 16).clamp(180.0, maxPanelHeight);
    final double availableAbove = (spaceAbove - 16).clamp(180.0, maxPanelHeight);

    final int optionCount =
        _filteredOptions.isEmpty ? 1 : _filteredOptions.length;
    final double idealListHeight =
        optionCount * optionRowHeight + listBottomPadding;

    double listHeightForSpace(double availableSpace) {
      final double listCap = availableSpace - searchSectionHeight;
      if (listCap <= 0) return 120.0;
      return idealListHeight < listCap ? idealListHeight : listCap;
    }

    final double listHeightBelow = listHeightForSpace(availableBelow);
    final double listHeightAbove = listHeightForSpace(availableAbove);

    final bool showAbove = listHeightBelow < idealListHeight &&
        listHeightAbove > listHeightBelow;
    final double listHeight = showAbove ? listHeightAbove : listHeightBelow;
    final double panelHeight = searchSectionHeight + listHeight;
    final Offset followerOffset = showAbove
        ? Offset(0, -panelHeight + 1)
        : Offset(0, size.height - 1);
    
    // Auto-scroll the page so the panel stays on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final double fieldTop = currentPosition.dy;
      final double fieldBottom = currentPosition.dy + size.height;
      final ScrollableState? scrollable = Scrollable.maybeOf(context);
      if (scrollable == null) return;

      final ScrollPosition position = scrollable.position;
      if (!position.hasContentDimensions) return;

      if (showAbove) {
        final double panelTop = fieldTop - panelHeight;
        if (panelTop < 16) {
          position.animateTo(
            (position.pixels + panelTop - 16).clamp(0.0, position.maxScrollExtent),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      } else {
        final double panelBottom = fieldBottom + panelHeight;
        if (panelBottom > screenHeight - 16) {
          final double scrollOffset = panelBottom - (screenHeight - 16);
          position.animateTo(
            (position.pixels + scrollOffset).clamp(0.0, position.maxScrollExtent),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      }
    });
    
    _entry = OverlayEntry(
      builder: (overlayContext) {
        final theme = Theme.of(overlayContext);
        final scheme = theme.colorScheme;
        final MediaQueryData overlayMediaQuery = MediaQuery.of(overlayContext);
        final double screenWidth = overlayMediaQuery.size.width;
        
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(onTap: _removeOverlay, behavior: HitTestBehavior.translucent),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: followerOffset,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: size.width,
                  height: panelHeight,
                  constraints: BoxConstraints(
                    maxWidth: screenWidth - 32,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 18, offset: const Offset(0, 6)),
                    ],
                    border: Border(
                      left: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(.4)),
                      right: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(.4)),
                      top: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(.4)),
                      bottom: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(.4)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          autofocus: false,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 1.0,
                          ),
                          decoration: InputDecoration(
                            hintText: widget.searchHintText ?? 'Search...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey[500],
                            ),
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(.4)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(.4)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: theme.colorScheme.primary),
                            ),
                            contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            isDense: true,
                            constraints: const BoxConstraints(),
                          ),
                          onChanged: _filterOptions,
                          onTap: () {
                            _searchFocusNode.requestFocus();
                          },
                        ),
                      ),
                      Expanded(
                        child: _filteredOptions.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                                child: Text(
                                  'No options found',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: theme.colorScheme.onSurface.withOpacity(.6),
                                  ),
                                ),
                              )
                            : Scrollbar(
                                controller: _scrollController,
                                thumbVisibility: true,
                                child: ListView.separated(
                                  controller: _scrollController,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(bottom: 12),
                                  itemCount: _filteredOptions.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                                  itemBuilder: (context, i) {
                                    final opt = _filteredOptions[i];
                                    final selected = opt == _value;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () {
                                          if (!widget.options.contains(opt)) {
                                            return;
                                          }
                                          
                                          _isUserSelecting = true;
                                          _removeOverlay();
                                          _value = opt;
                                          _previousWidgetValue = opt;
                                          _updateDisplayText();
                                          widget.onChanged(opt);
                                          setState(() {});
                                          
                                          Future.delayed(const Duration(milliseconds: 100), () {
                                            if (mounted) {
                                              _isUserSelecting = false;
                                            }
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  opt,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w400,
                                                    color: theme.colorScheme.onSurface,
                                                  ),
                                                ),
                                              ),
                                              if (selected)
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 8),
                                                  child: Icon(
                                                    Icons.check,
                                                    size: 20,
                                                    color: theme.colorScheme.primary,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_entry!);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.unfocus();
        _displayFocusNode.unfocus();
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
    // Unfocus search field when overlay is removed
    _searchFocusNode.unfocus();
  }
}



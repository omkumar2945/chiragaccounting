import 'package:flutter/material.dart';

import 'package:chirag_accounting/core/location/location_repository.dart';
import 'package:chirag_accounting/core/location/standard_address.dart';

class AddressFormController {
  AddressFormController({StandardAddress initialValue = const StandardAddress()})
    : addressLine1 = TextEditingController(text: initialValue.addressLine1),
      addressLine2 = TextEditingController(text: initialValue.addressLine2),
      country = TextEditingController(text: initialValue.countryName),
      state = TextEditingController(text: initialValue.stateName),
      city = TextEditingController(text: initialValue.cityName),
      district = TextEditingController(text: initialValue.district),
      pincode = TextEditingController(text: initialValue.pincode),
      locality = TextEditingController(text: initialValue.locality),
      postOffice = TextEditingController(text: initialValue.postOffice),
      _countryId = initialValue.countryId,
      _stateId = initialValue.stateId,
      _cityId = initialValue.cityId,
      _source = initialValue.source;

  final TextEditingController addressLine1;
  final TextEditingController addressLine2;
  final TextEditingController country;
  final TextEditingController state;
  final TextEditingController city;
  final TextEditingController district;
  final TextEditingController pincode;
  final TextEditingController locality;
  final TextEditingController postOffice;
  String _countryId;
  String _stateId;
  String _cityId;
  String _source;

  StandardAddress get value => StandardAddress(
    addressLine1: addressLine1.text.trim(),
    addressLine2: addressLine2.text.trim(),
    countryId: _countryId,
    countryName: country.text.trim(),
    stateId: _stateId,
    stateName: state.text.trim(),
    cityId: _cityId,
    cityName: city.text.trim(),
    district: district.text.trim(),
    pincode: pincode.text.trim(),
    locality: locality.text.trim(),
    postOffice: postOffice.text.trim(),
    source: _source,
  );

  void setValue(StandardAddress address) {
    addressLine1.text = address.addressLine1;
    addressLine2.text = address.addressLine2;
    country.text = address.countryName;
    state.text = address.stateName;
    city.text = address.cityName;
    district.text = address.district;
    pincode.text = address.pincode;
    locality.text = address.locality;
    postOffice.text = address.postOffice;
    _countryId = address.countryId;
    _stateId = address.stateId;
    _cityId = address.cityId;
    _source = address.source;
  }

  void copyFrom(AddressFormController other) => setValue(other.value);

  void dispose() {
    addressLine1.dispose();
    addressLine2.dispose();
    country.dispose();
    state.dispose();
    city.dispose();
    district.dispose();
    pincode.dispose();
    locality.dispose();
    postOffice.dispose();
  }
}

class AddressLocationForm extends StatefulWidget {
  const AddressLocationForm({
    required this.controller,
    this.title = 'Address & Location',
    this.repository,
    this.required = false,
    this.sameAsController,
    this.sameAsLabel = 'Same as Billing Address',
    this.onChanged,
    super.key,
  });

  final AddressFormController controller;
  final String title;
  final LocationRepository? repository;
  final bool required;
  final AddressFormController? sameAsController;
  final String sameAsLabel;
  final ValueChanged<StandardAddress>? onChanged;

  @override
  State<AddressLocationForm> createState() => _AddressLocationFormState();
}

class _AddressLocationFormState extends State<AddressLocationForm> {
  late final LocationRepository _repository;
  bool _sameAs = false;
  bool _loadingPincode = false;
  String _status = '';
  int _lookupSequence = 0;
  List<StandardAddress> _postalOptions = const <StandardAddress>[];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LocationRepository();
    widget.controller.pincode.addListener(_onPincodeChanged);
  }

  @override
  void dispose() {
    widget.controller.pincode.removeListener(_onPincodeChanged);
    super.dispose();
  }

  void _emitChange() => widget.onChanged?.call(widget.controller.value);

  Future<void> _onPincodeChanged() async {
    if (_sameAs) return;
    final pincode = widget.controller.pincode.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(pincode)) {
      if (mounted && (_loadingPincode || _status.isNotEmpty)) {
        setState(() {
          _loadingPincode = false;
          _status = '';
          _postalOptions = const <StandardAddress>[];
        });
      }
      return;
    }
    final sequence = ++_lookupSequence;
    setState(() {
      _loadingPincode = true;
      _status = 'Looking up postal details...';
    });
    final options = await _repository.lookupPincode(pincode);
    if (!mounted || sequence != _lookupSequence) return;
    setState(() {
      _loadingPincode = false;
      _postalOptions = options;
      if (options.isEmpty) {
        _status = 'Location service unavailable. Enter details manually.';
      } else {
        _applyPostalOption(options.first);
        _status = options.first.source == 'local-catalog'
            ? 'Offline location match applied. You can edit any field.'
            : 'Postal details applied. Select a locality if needed.';
      }
    });
    _emitChange();
  }

  void _applyPostalOption(StandardAddress option) {
    final current = widget.controller.value;
    widget.controller.setValue(
      current.copyWith(
        countryId: option.countryId,
        countryName: option.countryName,
        stateId: option.stateId,
        stateName: option.stateName,
        cityId: option.cityId,
        cityName: option.cityName,
        district: option.district,
        pincode: option.pincode,
        locality: option.locality,
        postOffice: option.postOffice,
        source: option.source,
      ),
    );
  }

  void _setSameAs(bool selected) {
    setState(() => _sameAs = selected);
    if (selected && widget.sameAsController != null) {
      widget.controller.copyFrom(widget.sameAsController!);
      _emitChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _sameAs;
    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.sameAsController != null)
                Flexible(
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _sameAs,
                    title: Text(widget.sameAsLabel),
                    onChanged: (value) => _setSameAs(value ?? false),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: widget.controller.addressLine1,
            enabled: !disabled,
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: widget.required ? 'Address line 1 *' : 'Address line 1',
              hintText: 'Building, street and landmark',
              border: const OutlineInputBorder(),
            ),
            validator: widget.required
                ? (value) => value == null || value.trim().isEmpty
                    ? 'Address is required'
                    : null
                : null,
            onChanged: (_) => _emitChange(),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: widget.controller.addressLine2,
            enabled: !disabled,
            decoration: const InputDecoration(
              labelText: 'Address line 2',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _emitChange(),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 3 : constraints.maxWidth >= 480 ? 2 : 1;
              final width = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - ((columns - 1) * 10)) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  SizedBox(
                    width: width,
                    child: _SearchableEditableField(
                      controller: widget.controller.country,
                      label: 'Country',
                      enabled: !disabled,
                      optionsBuilder: (query) => LocationRepository.countries
                          .where((country) => country.name.toLowerCase().contains(query.toLowerCase()))
                          .map((country) => country.name),
                      onSelected: (value) {
                        final country = LocationRepository.countries
                            .where((option) => option.name == value)
                            .firstOrNull;
                        widget.controller._countryId = country?.id ?? '';
                        widget.controller.state.clear();
                        widget.controller.city.clear();
                        _emitChange();
                      },
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _SearchableEditableField(
                      controller: widget.controller.state,
                      label: 'State / Union Territory',
                      enabled: !disabled,
                      optionsBuilder: (query) => _repository.searchStates(
                        query,
                        countryId: widget.controller._countryId,
                      ),
                      onSelected: (_) {
                        widget.controller.city.clear();
                        widget.controller._stateId = '';
                        _emitChange();
                      },
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _SearchableEditableField(
                      controller: widget.controller.city,
                      label: 'City',
                      enabled: !disabled,
                      optionsBuilder: (query) => _repository
                          .searchCities(state: widget.controller.state.text, query: query)
                          .map((option) => option.city),
                      onSelected: (value) {
                        final option = _repository
                            .searchCities(state: widget.controller.state.text, query: value)
                            .where((city) => city.city == value)
                            .firstOrNull;
                        if (option != null) {
                          widget.controller.pincode.text = option.pincode;
                        }
                        widget.controller._cityId = '';
                        _emitChange();
                      },
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: TextFormField(
                      key: const ValueKey('central-address-pincode'),
                      controller: widget.controller.pincode,
                      enabled: !disabled,
                      keyboardType: TextInputType.number,
                      maxLength: widget.controller._countryId == 'IN' ? 6 : null,
                      decoration: InputDecoration(
                        labelText: 'Pincode / Postal Code',
                        border: const OutlineInputBorder(),
                        counterText: '',
                        suffixIcon: _loadingPincode
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : const Icon(Icons.location_searching_outlined),
                      ),
                      onChanged: (_) => _emitChange(),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _SearchableEditableField(
                      controller: widget.controller.locality,
                      label: 'Area / Locality',
                      enabled: !disabled,
                      optionsBuilder: (query) => _postalOptions
                          .map((option) => option.locality.isEmpty ? option.postOffice : option.locality)
                          .where((value) => value.isNotEmpty && value.toLowerCase().contains(query.toLowerCase())),
                      onSelected: (_) => _emitChange(),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: TextFormField(
                      controller: widget.controller.district,
                      enabled: !disabled,
                      decoration: const InputDecoration(
                        labelText: 'District',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _emitChange(),
                    ),
                  ),
                ],
              );
            },
          ),
          if (_status.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(
                  _postalOptions.isEmpty ? Icons.cloud_off_outlined : Icons.check_circle_outline,
                  size: 16,
                  color: _postalOptions.isEmpty ? Colors.orange.shade800 : Colors.green.shade700,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _status,
                    style: TextStyle(
                      fontSize: 12,
                      color: _postalOptions.isEmpty ? Colors.orange.shade900 : Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchableEditableField extends StatefulWidget {
  const _SearchableEditableField({
    required this.controller,
    required this.label,
    required this.optionsBuilder,
    required this.onSelected,
    required this.enabled,
  });

  final TextEditingController controller;
  final String label;
  final Iterable<String> Function(String query) optionsBuilder;
  final ValueChanged<String> onSelected;
  final bool enabled;

  @override
  State<_SearchableEditableField> createState() => _SearchableEditableFieldState();
}

class _SearchableEditableFieldState extends State<_SearchableEditableField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) => widget.optionsBuilder(value.text),
      onSelected: widget.onSelected,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.search, size: 19),
          ),
          onChanged: (_) {},
          onFieldSubmitted: (_) => onSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final values = options.toList(growable: false);
        if (values.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: values.length,
                itemBuilder: (context, index) => ListTile(
                  dense: true,
                  title: Text(values[index]),
                  onTap: () => onSelected(values[index]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
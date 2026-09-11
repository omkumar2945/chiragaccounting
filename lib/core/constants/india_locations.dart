IndianCityOption? findIndianCityByPincode(String pincode) {
  final normalizedPincode = pincode.trim();
  for (final option in kAllIndianCityOptions) {
    if (option.pincode == normalizedPincode) {
      return option;
    }
  }

  return null;
}
class IndianCityOption {
  final String state;
  final String city;
  final String pincode;

  const IndianCityOption({
    required this.state,
    required this.city,
    required this.pincode,
  });

  String get label => city;
  String get subtitle => '$state - PIN: $pincode';
}

const Map<String, List<IndianCityOption>> kIndianCitiesByState = {
  'Andaman and Nicobar Islands': [
    IndianCityOption(
      state: 'Andaman and Nicobar Islands',
      city: 'Port Blair',
      pincode: '744101',
    ),
  ],
  'Andhra Pradesh': [
    IndianCityOption(
      state: 'Andhra Pradesh',
      city: 'Visakhapatnam',
      pincode: '530001',
    ),
    IndianCityOption(
      state: 'Andhra Pradesh',
      city: 'Vijayawada',
      pincode: '520001',
    ),
    IndianCityOption(
      state: 'Andhra Pradesh',
      city: 'Tirupati',
      pincode: '517501',
    ),
  ],
  'Arunachal Pradesh': [
    IndianCityOption(
      state: 'Arunachal Pradesh',
      city: 'Itanagar',
      pincode: '791111',
    ),
  ],
  'Assam': [
    IndianCityOption(state: 'Assam', city: 'Guwahati', pincode: '781001'),
    IndianCityOption(state: 'Assam', city: 'Silchar', pincode: '788001'),
  ],
  'Bihar': [
    IndianCityOption(state: 'Bihar', city: 'Patna', pincode: '800001'),
    IndianCityOption(state: 'Bihar', city: 'Gaya', pincode: '823001'),
  ],
  'Chandigarh': [
    IndianCityOption(
      state: 'Chandigarh',
      city: 'Chandigarh',
      pincode: '160017',
    ),
  ],
  'Chhattisgarh': [
    IndianCityOption(state: 'Chhattisgarh', city: 'Raipur', pincode: '492001'),
    IndianCityOption(
      state: 'Chhattisgarh',
      city: 'Bilaspur',
      pincode: '495001',
    ),
  ],
  'Dadra and Nagar Haveli and Daman and Diu': [
    IndianCityOption(
      state: 'Dadra and Nagar Haveli and Daman and Diu',
      city: 'Daman',
      pincode: '396210',
    ),
    IndianCityOption(
      state: 'Dadra and Nagar Haveli and Daman and Diu',
      city: 'Silvassa',
      pincode: '396230',
    ),
  ],
  'Delhi': [
    IndianCityOption(state: 'Delhi', city: 'New Delhi', pincode: '110001'),
    IndianCityOption(state: 'Delhi', city: 'Dwarka', pincode: '110075'),
  ],
  'Goa': [
    IndianCityOption(state: 'Goa', city: 'Panaji', pincode: '403001'),
    IndianCityOption(state: 'Goa', city: 'Margao', pincode: '403601'),
  ],
  'Gujarat': [
    IndianCityOption(state: 'Gujarat', city: 'Ahmedabad', pincode: '380001'),
    IndianCityOption(state: 'Gujarat', city: 'Surat', pincode: '395003'),
    IndianCityOption(state: 'Gujarat', city: 'Vadodara', pincode: '390001'),
  ],
  'Haryana': [
    IndianCityOption(state: 'Haryana', city: 'Gurugram', pincode: '122001'),
    IndianCityOption(state: 'Haryana', city: 'Faridabad', pincode: '121001'),
  ],
  'Himachal Pradesh': [
    IndianCityOption(
      state: 'Himachal Pradesh',
      city: 'Shimla',
      pincode: '171001',
    ),
  ],
  'Jammu and Kashmir': [
    IndianCityOption(
      state: 'Jammu and Kashmir',
      city: 'Srinagar',
      pincode: '190001',
    ),
    IndianCityOption(
      state: 'Jammu and Kashmir',
      city: 'Jammu',
      pincode: '180001',
    ),
  ],
  'Jharkhand': [
    IndianCityOption(state: 'Jharkhand', city: 'Ranchi', pincode: '834001'),
    IndianCityOption(state: 'Jharkhand', city: 'Jamshedpur', pincode: '831001'),
  ],
  'Karnataka': [
    IndianCityOption(state: 'Karnataka', city: 'Bengaluru', pincode: '560001'),
    IndianCityOption(state: 'Karnataka', city: 'Mysuru', pincode: '570001'),
    IndianCityOption(state: 'Karnataka', city: 'Mangaluru', pincode: '575001'),
  ],
  'Kerala': [
    IndianCityOption(
      state: 'Kerala',
      city: 'Thiruvananthapuram',
      pincode: '695001',
    ),
    IndianCityOption(state: 'Kerala', city: 'Kochi', pincode: '682001'),
    IndianCityOption(state: 'Kerala', city: 'Kozhikode', pincode: '673001'),
  ],
  'Ladakh': [IndianCityOption(state: 'Ladakh', city: 'Leh', pincode: '194101')],
  'Lakshadweep': [
    IndianCityOption(
      state: 'Lakshadweep',
      city: 'Kavaratti',
      pincode: '682555',
    ),
  ],
  'Madhya Pradesh': [
    IndianCityOption(
      state: 'Madhya Pradesh',
      city: 'Bhopal',
      pincode: '462001',
    ),
    IndianCityOption(
      state: 'Madhya Pradesh',
      city: 'Indore',
      pincode: '452001',
    ),
    IndianCityOption(
      state: 'Madhya Pradesh',
      city: 'Jabalpur',
      pincode: '482001',
    ),
  ],
  'Maharashtra': [
    IndianCityOption(state: 'Maharashtra', city: 'Mumbai', pincode: '400001'),
    IndianCityOption(state: 'Maharashtra', city: 'Pune', pincode: '411001'),
    IndianCityOption(state: 'Maharashtra', city: 'Nagpur', pincode: '440001'),
  ],
  'Manipur': [
    IndianCityOption(state: 'Manipur', city: 'Imphal', pincode: '795001'),
  ],
  'Meghalaya': [
    IndianCityOption(state: 'Meghalaya', city: 'Shillong', pincode: '793001'),
  ],
  'Mizoram': [
    IndianCityOption(state: 'Mizoram', city: 'Aizawl', pincode: '796001'),
  ],
  'Nagaland': [
    IndianCityOption(state: 'Nagaland', city: 'Kohima', pincode: '797001'),
    IndianCityOption(state: 'Nagaland', city: 'Dimapur', pincode: '797112'),
  ],
  'Odisha': [
    IndianCityOption(state: 'Odisha', city: 'Bhubaneswar', pincode: '751001'),
    IndianCityOption(state: 'Odisha', city: 'Cuttack', pincode: '753001'),
  ],
  'Puducherry': [
    IndianCityOption(
      state: 'Puducherry',
      city: 'Puducherry',
      pincode: '605001',
    ),
  ],
  'Punjab': [
    IndianCityOption(state: 'Punjab', city: 'Ludhiana', pincode: '141001'),
    IndianCityOption(state: 'Punjab', city: 'Amritsar', pincode: '143001'),
  ],
  'Rajasthan': [
    IndianCityOption(state: 'Rajasthan', city: 'Jaipur', pincode: '302001'),
    IndianCityOption(state: 'Rajasthan', city: 'Jodhpur', pincode: '342001'),
  ],
  'Sikkim': [
    IndianCityOption(state: 'Sikkim', city: 'Gangtok', pincode: '737101'),
  ],
  'Tamil Nadu': [
    IndianCityOption(state: 'Tamil Nadu', city: 'Chennai', pincode: '600001'),
    IndianCityOption(
      state: 'Tamil Nadu',
      city: 'Coimbatore',
      pincode: '641001',
    ),
    IndianCityOption(state: 'Tamil Nadu', city: 'Madurai', pincode: '625001'),
  ],
  'Telangana': [
    IndianCityOption(state: 'Telangana', city: 'Hyderabad', pincode: '500001'),
    IndianCityOption(state: 'Telangana', city: 'Warangal', pincode: '506002'),
  ],
  'Tripura': [
    IndianCityOption(state: 'Tripura', city: 'Agartala', pincode: '799001'),
  ],
  'Uttar Pradesh': [
    IndianCityOption(
      state: 'Uttar Pradesh',
      city: 'Lucknow',
      pincode: '226001',
    ),
    IndianCityOption(state: 'Uttar Pradesh', city: 'Kanpur', pincode: '208001'),
    IndianCityOption(
      state: 'Uttar Pradesh',
      city: 'Varanasi',
      pincode: '221001',
    ),
  ],
  'Uttarakhand': [
    IndianCityOption(state: 'Uttarakhand', city: 'Dehradun', pincode: '248001'),
    IndianCityOption(state: 'Uttarakhand', city: 'Haridwar', pincode: '249401'),
  ],
  'West Bengal': [
    IndianCityOption(state: 'West Bengal', city: 'Kolkata', pincode: '700001'),
    IndianCityOption(state: 'West Bengal', city: 'Siliguri', pincode: '734001'),
  ],
};

final List<String> kIndianStates = kIndianCitiesByState.keys.toList(
  growable: false,
);

final List<IndianCityOption> kAllIndianCityOptions = kIndianCitiesByState.values
    .expand((cities) => cities)
    .toList(growable: false);

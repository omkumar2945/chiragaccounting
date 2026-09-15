import 'standard_address.dart';

final List<String> indianStateOptions =
    kIndianGstStateCodes.keys.map(_titleCase).toList(growable: false)..sort();

const Map<String, List<String>> indianCitiesByState = <String, List<String>>{
  'Andhra Pradesh': <String>['Visakhapatnam', 'Vijayawada', 'Guntur', 'Tirupati'],
  'Assam': <String>['Guwahati', 'Dibrugarh', 'Silchar', 'Jorhat'],
  'Bihar': <String>['Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur'],
  'Chandigarh': <String>['Chandigarh'],
  'Chhattisgarh': <String>['Raipur', 'Bhilai', 'Bilaspur', 'Korba'],
  'Delhi': <String>['New Delhi', 'Delhi', 'Dwarka', 'Rohini'],
  'Goa': <String>['Panaji', 'Margao', 'Vasco da Gama', 'Mapusa'],
  'Gujarat': <String>['Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Gandhinagar'],
  'Haryana': <String>['Gurugram', 'Faridabad', 'Panipat', 'Hisar'],
  'Karnataka': <String>['Bengaluru', 'Mysuru', 'Hubballi', 'Mangaluru'],
  'Kerala': <String>['Thiruvananthapuram', 'Kochi', 'Kozhikode', 'Thrissur'],
  'Madhya Pradesh': <String>['Indore', 'Bhopal', 'Jabalpur', 'Gwalior'],
  'Maharashtra': <String>['Mumbai', 'Pune', 'Nagpur', 'Nashik', 'Thane'],
  'Odisha': <String>['Bhubaneswar', 'Cuttack', 'Rourkela', 'Puri'],
  'Punjab': <String>['Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala'],
  'Rajasthan': <String>['Jaipur', 'Jodhpur', 'Udaipur', 'Kota', 'Ajmer'],
  'Tamil Nadu': <String>['Chennai', 'Coimbatore', 'Madurai', 'Tiruchirappalli'],
  'Telangana': <String>['Hyderabad', 'Warangal', 'Nizamabad', 'Karimnagar'],
  'Uttar Pradesh': <String>['Lucknow', 'Kanpur', 'Noida', 'Agra', 'Varanasi'],
  'Uttarakhand': <String>['Dehradun', 'Haridwar', 'Haldwani', 'Roorkee'],
  'West Bengal': <String>['Kolkata', 'Howrah', 'Siliguri', 'Durgapur'],
};

String _titleCase(String value) => value
    .split(' ')
    .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

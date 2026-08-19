const fetch = globalThis.fetch;

const PINCODE_PREFIX_MAP = {
  // Delhi & NCR
  '110': { state: 'Delhi', city: 'New Delhi' },
  '121': { state: 'Haryana', city: 'Faridabad' },
  '122': { state: 'Haryana', city: 'Gurugram' },
  '131': { state: 'Haryana', city: 'Sonipat' },
  '201': { state: 'Uttar Pradesh', city: 'Noida / Ghaziabad' },

  // Maharashtra & Goa
  '400': { state: 'Maharashtra', city: 'Mumbai' },
  '401': { state: 'Maharashtra', city: 'Thane / Palghar' },
  '402': { state: 'Maharashtra', city: 'Raigad' },
  '403': { state: 'Goa', city: 'Panaji / Margao' },
  '411': { state: 'Maharashtra', city: 'Pune' },
  '412': { state: 'Maharashtra', city: 'Pune Rural' },
  '413': { state: 'Maharashtra', city: 'Solapur' },
  '414': { state: 'Maharashtra', city: 'Ahilya Nagar (Ahmednagar)' },
  '415': { state: 'Maharashtra', city: 'Satara' },
  '416': { state: 'Maharashtra', city: 'Kolhapur / Sangli' },
  '421': { state: 'Maharashtra', city: 'Kalyan / Dombivli' },
  '422': { state: 'Maharashtra', city: 'Nashik' },
  '423': { state: 'Maharashtra', city: 'Malegaon / Nashik' },
  '424': { state: 'Maharashtra', city: 'Jalgaon' },
  '425': { state: 'Maharashtra', city: 'Jalgaon / Dhule' },
  '431': { state: 'Maharashtra', city: 'Hingoli / Nanded / Chhatrapati Sambhajinagar' },
  '440': { state: 'Maharashtra', city: 'Nagpur' },
  '441': { state: 'Maharashtra', city: 'Nagpur Rural / Bhandara' },
  '442': { state: 'Maharashtra', city: 'Wardha / Chandrapur' },
  '443': { state: 'Maharashtra', city: 'Buldhana' },
  '444': { state: 'Maharashtra', city: 'Akola / Amravati' },
  '445': { state: 'Maharashtra', city: 'Yavatmal' },

  // Karnataka
  '560': { state: 'Karnataka', city: 'Bengaluru' },
  '561': { state: 'Karnataka', city: 'Bengaluru Rural' },
  '570': { state: 'Karnataka', city: 'Mysuru' },
  '580': { state: 'Karnataka', city: 'Hubballi / Dharwad' },
  '575': { state: 'Karnataka', city: 'Mangaluru' },

  // Tamil Nadu
  '600': { state: 'Tamil Nadu', city: 'Chennai' },
  '641': { state: 'Tamil Nadu', city: 'Coimbatore' },
  '625': { state: 'Tamil Nadu', city: 'Madurai' },

  // Telangana & AP
  '500': { state: 'Telangana', city: 'Hyderabad' },
  '520': { state: 'Andhra Pradesh', city: 'Vijayawada' },
  '530': { state: 'Andhra Pradesh', city: 'Visakhapatnam' },

  // Gujarat
  '380': { state: 'Gujarat', city: 'Ahmedabad' },
  '390': { state: 'Gujarat', city: 'Vadodara' },
  '395': { state: 'Gujarat', city: 'Surat' },
  '360': { state: 'Gujarat', city: 'Rajkot' },

  // Rajasthan
  '302': { state: 'Rajasthan', city: 'Jaipur' },
  '342': { state: 'Rajasthan', city: 'Jodhpur' },
  '313': { state: 'Rajasthan', city: 'Udaipur' },

  // West Bengal & North East
  '700': { state: 'West Bengal', city: 'Kolkata' },
  '734': { state: 'West Bengal', city: 'Siliguri' },
  '781': { state: 'Assam', city: 'Guwahati' },

  // Uttar Pradesh & Uttarakhand
  '226': { state: 'Uttar Pradesh', city: 'Lucknow' },
  '208': { state: 'Uttar Pradesh', city: 'Kanpur' },
  '221': { state: 'Uttar Pradesh', city: 'Varanasi' },
  '211': { state: 'Uttar Pradesh', city: 'Prayagraj' },
  '248': { state: 'Uttarakhand', city: 'Dehradun' },

  // Bihar & Jharkhand
  '800': { state: 'Bihar', city: 'Patna' },
  '834': { state: 'Jharkhand', city: 'Ranchi' },
  '831': { state: 'Jharkhand', city: 'Jamshedpur' },

  // MP & Chhattisgarh
  '462': { state: 'Madhya Pradesh', city: 'Bhopal' },
  '452': { state: 'Madhya Pradesh', city: 'Indore' },
  '492': { state: 'Chhattisgarh', city: 'Raipur' },

  // Punjab, HP, J&K
  '160': { state: 'Chandigarh', city: 'Chandigarh' },
  '141': { state: 'Punjab', city: 'Ludhiana' },
  '143': { state: 'Punjab', city: 'Amritsar' },
  '171': { state: 'Himachal Pradesh', city: 'Shimla' },
  '190': { state: 'Jammu & Kashmir', city: 'Srinagar' },
  '180': { state: 'Jammu & Kashmir', city: 'Jammu' },

  // Kerala
  '695': { state: 'Kerala', city: 'Thiruvananthapuram' },
  '682': { state: 'Kerala', city: 'Kochi' }
};

const REGION_DIGIT_MAP = {
  '1': { state: 'Northern Region', city: 'Northern Region' },
  '2': { state: 'Uttar Pradesh / Uttarakhand', city: 'UP Region' },
  '3': { state: 'Rajasthan / Gujarat', city: 'Western Region' },
  '4': { state: 'Maharashtra / MP / Chhattisgarh / Goa', city: 'Central Region' },
  '5': { state: 'Andhra Pradesh / Telangana / Karnataka', city: 'Southern Region' },
  '6': { state: 'Tamil Nadu / Kerala', city: 'Southern Region' },
  '7': { state: 'West Bengal / Odisha / North East', city: 'Eastern Region' },
  '8': { state: 'Bihar / Jharkhand', city: 'Eastern Region' }
};

async function lookupPincode(pin) {
  const cleanPin = String(pin || '').trim();
  if (!cleanPin || cleanPin.length !== 6 || !/^\d+$/.test(cleanPin)) {
    return null;
  }

  // 1st Priority: India Post API with 2.5s timeout
  try {
    const res = await fetch(`https://api.postalpincode.in/pincode/${cleanPin}`, {
      signal: AbortSignal.timeout(2500)
    });
    const data = await res.json();
    if (data && data[0]?.Status === 'Success' && data[0]?.PostOffice?.length > 0) {
      const poList = data[0].PostOffice;
      const mainPo = poList[0];
      const city = mainPo.District || mainPo.Division || mainPo.Block || mainPo.Name || '';
      const state = mainPo.State || '';

      if (city || state) {
        return {
          pincode: cleanPin,
          city,
          state,
          district: mainPo.District || city,
          source: 'IndiaPost'
        };
      }
    }
  } catch (err) {
    // Suppress network/timeout errors and fallback immediately
  }

  // 2nd Priority: Zippopotam API
  try {
    const res = await fetch(`https://api.zippopotam.us/IN/${cleanPin}`, {
      signal: AbortSignal.timeout(2500)
    });
    const data = await res.json();
    if (data && data.places && data.places.length > 0) {
      const place = data.places[0];
      const city = place['place name'] || place['state abbreviation'] || '';
      const state = place.state || '';
      if (city || state) {
        return {
          pincode: cleanPin,
          city,
          state,
          district: place['place name'] || city,
          source: 'Zippopotam'
        };
      }
    }
  } catch (err) {}

  // 3rd Priority: Smart Pincode Prefix Dictionary
  const prefix3 = cleanPin.substring(0, 3);
  if (PINCODE_PREFIX_MAP[prefix3]) {
    const match = PINCODE_PREFIX_MAP[prefix3];
    return {
      pincode: cleanPin,
      city: match.city,
      state: match.state,
      district: match.city,
      source: 'LocalDictionary'
    };
  }

  const prefix1 = cleanPin.substring(0, 1);
  if (REGION_DIGIT_MAP[prefix1]) {
    const match = REGION_DIGIT_MAP[prefix1];
    return {
      pincode: cleanPin,
      city: match.city,
      state: match.state,
      district: match.city,
      source: 'RegionFallback'
    };
  }

  return {
    pincode: cleanPin,
    city: 'Central',
    state: 'India',
    district: 'Central',
    source: 'DefaultFallback'
  };
}

module.exports = { lookupPincode };

# Locale

Ref data: countries, currencies, languages, locations.

---

## Countries

```dart
// Dart
final countries = await locale.listCountries();

for (final country in countries.countries) {
    print('${country.name}: ${country.code}'); // Afghanistan: AF
}
```

```python
# Python
countries = locale.list_countries()
for country in countries['countries']:
    print(f"{country['name']}: {country['code']}")
```

```typescript
// TypeScript
const countries = await locale.listCountries();
countries.countries.forEach(c => console.log(`${c.name}: ${c.code}`));
```

---

## EU Countries

```dart
final euCountries = await locale.listCountriesEU();
// Returns only EU member states
```

---

## Phone Codes

```dart
final codes = await locale.listCountriesPhones();

for (final entry in codes.phones) {
    print('${entry.countryName}: +${entry.code}'); // Germany: +49
}
```

---

## Continents

```dart
final continents = await locale.listContinents();
// Africa, Americas, Antarctica, Asia, Europe, Oceania
```

---

## Currencies

```dart
final currencies = await locale.listCurrencies();

for (final currency in currencies.currencies) {
    print('${currency.name}: ${currency.symbol}'); // US Dollar: $
}
```

---

## Languages

```dart
final languages = await locale.listLanguages();

for (final lang in languages.languages) {
    print('${lang.name}: ${lang.code}'); // English: en
}
```

---

## User Location

Approx location from IP.

```dart
final location = await locale.get();

print(location.ip);              // 192.168.1.1
print(location.countryCode);     // US
print(location.country);         // United States
print(location.continent);       // North America
print(location.continentCode);   // NA
print(location.eu);              // false
print(location.currency);        // USD
```

---

## Use Cases

- **Dropdowns:** country/language selectors
- **Validation:** phone format by country
- **Localization:** currency by region
- **Compliance:** EU/non-EU detect

---

## Caching

Locale data rare change. Cache responses:

```dart
// Cache for 24 hours
final countries = await cacheOrFetch(
    key: 'countries',
    ttl: Duration(hours: 24),
    fetch: () => locale.listCountries(),
);
```

---

## Related

- Permissions for location-based access
- Functions for IP-based logic

import 'dart:convert';

import 'package:mbis/src/network/api_client.dart';

import '../../domain/entities/customer.dart';
import 'customer_repository.dart';

/// Implementasi nyata: ambil daftar nasabah dari backend via [ApiClient] (existing).
/// Office-scope dipaksa DI SERVER — klien hanya menampilkan yang diizinkan.
class ApiCustomerRepository implements CustomerRepository {
  final ApiClient _client;

  ApiCustomerRepository(this._client);

  @override
  Future<List<Customer>> list() async {
    final resp = await _client.get('/api/customers');
    final data = jsonDecode(resp.body) as List<dynamic>;
    return data
        .map((e) => Customer.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

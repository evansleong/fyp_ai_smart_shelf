import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_stripe/flutter_stripe.dart';

const String cartsApiBase = 'https://twhhc88zla.execute-api.ap-southeast-1.amazonaws.com/prod';
const String paymentsApiBase = 'https://e036h7bhn2.execute-api.ap-southeast-1.amazonaws.com/prod';
const String cartsApiKey = '';

Future<void> checkout({
  required String customerId,
  required String shopId,
  required String name,
  required String phone,
  required String email,
  required double amount,
}) async {
  final createIntentResp = await http.post(
    Uri.parse('$paymentsApiBase/payments/create-intent'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'customer_id': customerId,
      'shop_id': shopId,
      'amount': (amount * 100).round(),
    }),
  );
  if (createIntentResp.statusCode != 200) {
    throw Exception('Failed to create payment intent: ${createIntentResp.body}');
  }
  final Map<String, dynamic> piData = jsonDecode(createIntentResp.body) as Map<String, dynamic>;
  final String clientSecret = piData['clientSecret'] as String;
  final String paymentIntentId = piData['paymentIntentId'] as String;

  await Stripe.instance.initPaymentSheet(
    paymentSheetParameters: SetupPaymentSheetParameters(
      paymentIntentClientSecret: clientSecret,
      merchantDisplayName: 'SmartShelf',
      style: ThemeMode.system,
      allowsDelayedPaymentMethods: true,
    ),
  );

  await Stripe.instance.presentPaymentSheet();

  final Map<String, dynamic> finalizePayload = {
    'action': 'finalize_checkout',
    'params': {
      'shop_id': shopId,
      'customer_id': customerId,
      'payment_status': 'succeeded',
      'payment_reference': paymentIntentId,
      'payment_method': 'card',
      'name': name,
      'phone': phone,
      'email': email,
    }
  };

  final finalizeResp = await http.post(
    Uri.parse('$cartsApiBase/carts'),
    headers: {
      'Content-Type': 'application/json',
      if (cartsApiKey.isNotEmpty) 'x-api-key': cartsApiKey,
    },
    body: jsonEncode(finalizePayload),
  );

  if (finalizeResp.statusCode != 200) {
    throw Exception('Finalize checkout failed: ${finalizeResp.body}');
  }

  final Map<String, dynamic> finalizeData = jsonDecode(finalizeResp.body) as Map<String, dynamic>;
  finalizeData.toString();
}

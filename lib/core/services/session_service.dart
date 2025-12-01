class SessionService {
  static final SessionService _instance = SessionService._internal();

  factory SessionService() {
    return _instance;
  }

  SessionService._internal();

  String? _name;
  String? _phone;
  String? _email;

  String? get name => _name;
  String? get phone => _phone;
  String? get email => _email;

  void updateSession({String? name, String? phone, String? email}) {
    if (name != null) _name = name;
    if (phone != null) _phone = phone;
    if (email != null) _email = email;
  }

  void clearSession() {
    _name = null;
    _phone = null;
    _email = null;
  }
}

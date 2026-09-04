import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

/// Servicio singleton para gestionar la sesión del usuario/repartidor actual.
/// Persiste la selección en SharedPreferences y expone el sellerId actual.
class UserSessionService {
  static final UserSessionService _instance = UserSessionService._internal();
  factory UserSessionService() => _instance;
  UserSessionService._internal();

  static const String _prefsKey = 'current_seller_id';

  int? _currentSellerId;
  String? _currentSellerName;
  bool _isLoaded = false;

  /// ID del repartidor actual. Default: 1 (Moy) si no hay sesión cargada.
  int get currentSellerId => _currentSellerId ?? 1;

  /// Nombre del repartidor actual.
  String get currentSellerName => _currentSellerName ?? '';

  /// Indica si ya se cargó la sesión desde SharedPreferences.
  bool get isLoaded => _isLoaded;

  /// Indica si hay una sesión activa guardada.
  bool get hasSession => _currentSellerId != null;

  /// Carga la sesión persistida desde SharedPreferences.
  /// Si no hay sesión guardada, deja _currentSellerId como null
  /// (el caller decidirá si mostrar la pantalla de selección).
  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sellerId = prefs.getInt(_prefsKey);
    if (sellerId != null) {
      _currentSellerId = sellerId;
      // Intentar cargar el nombre desde la BD
      try {
        final db = DatabaseService();
        await db.init();
        final usuario = await db.getUsuarioById(sellerId);
        _currentSellerName = usuario?.nombre ?? '';
      } catch (e) {
        _currentSellerName = '';
      }
    }
    _isLoaded = true;
  }

  /// Establece el repartidor actual y lo persiste.
  Future<void> setCurrentSeller(int sellerId, String sellerName) async {
    _currentSellerId = sellerId;
    _currentSellerName = sellerName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, sellerId);
  }

  /// Limpia la sesión actual (para cambiar de usuario).
  Future<void> clearSession() async {
    _currentSellerId = null;
    _currentSellerName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  /// Devuelve el ID compuesto para PersistentDeliveryStates.
  String get persistentStateId => 'current_$currentSellerId';
}
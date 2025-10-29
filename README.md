# Sistema de Gestión para Vendedor Itinerante

Una aplicación móvil desarrollada en Flutter para ayudar a vendedores itinerantes a gestionar sus repartos, ventas, clientes y gastos. El sistema utiliza almacenamiento local con Drift y sincroniza datos con Google Sheets como almacén remoto.

## 🎯 Características Principales

- **Gestión de Repartos**: Seguimiento en tiempo real de rutas de entrega con temporizador integrado
- **Registro de Ventas**: Interfaz intuitiva para registrar ventas por cliente
- **Gestión de Clientes**: Base de datos completa con información detallada y estadísticas
- **Sincronización en la Nube**: Integración con Google Sheets para respaldo y análisis
- **Sistema de Puntuación**: Algoritmo inteligente para calificar clientes basado en comportamiento de compra
- **Registro de Gastos**: (En desarrollo) Seguimiento de costos operativos
- **Logs del Sistema**: Registro de actividades para debugging y auditoría

## 🏗️ Arquitectura

### Tecnologías
- **Flutter**: Framework de UI multiplataforma
- **Dart**: Lenguaje de programación
- **Drift**: ORM para SQLite con generación de código
- **Google Sheets API**: Sincronización con hojas de cálculo
- **Material Design**: Diseño de interfaz consistente

### Estructura del Proyecto
```
lib/
├── main.dart                 # Punto de entrada de la aplicación
├── data/
│   ├── database.dart         # Definición de esquemas de BD (Drift)
│   ├── database.g.dart       # Código generado por Drift
│   └── delivery_state.dart   # Estado global del reparto activo
├── services/
│   ├── sync_service.dart     # Servicio central de sincronización
│   ├── google_sheets_service.dart # Integración con Google Sheets
│   ├── database_service.dart # Operaciones CRUD de base de datos
│   └── delivery_service.dart # Lógica específica de repartos
├── controllers/
│   └── delivery_controller.dart # Controlador para gestión de repartos
├── pages/                    # Páginas de la interfaz de usuario
│   ├── section_delivery_page.dart # Gestión de repartos
│   ├── section2_page.dart    # Registro de ventas
│   ├── nuevo_cliente_page.dart # Crear nuevo cliente
│   ├── editar_clientes_page.dart # Editar clientes existentes
│   ├── synchronization_page.dart # Interfaz de sincronización
│   └── logs_page.dart        # Visualización de logs
└── widgets/                  # Componentes reutilizables
    ├── sync_action_button.dart
    ├── sync_dialogs.dart
    └── venta_form.dart
```

## 📊 Modelo de Datos

### Tablas Principales

#### Ventas (Sales)
- `id`: Identificador único
- `date`: Fecha de la venta
- `clientId`: ID del cliente (FK)
- `quantity`: Cantidad vendida (kg)
- `price`: Precio unitario
- `total`: Total de la venta
- `notesId`: ID de notas (opcional)
- `deliveryNumber`: Número de reparto (FK)

#### Repartos (Deliveries)
- `deliveryNumber`: Número único del reparto
- `date`: Fecha del reparto
- `durationSeconds`: Duración en segundos
- `avgPrice`: Precio promedio
- `kilograms`: Total de kg repartidos
- `boxes`: Número de cajas
- `remaining`: Cantidad restante
- `seller`: Nombre del vendedor
- `total`: Total del reparto

#### Clientes (Clientes)
Información detallada incluyendo:
- Datos básicos: nombre, contacto, ubicación, teléfono
- Horarios de atención
- Estadísticas calculadas: kg totales, moda de compra, máximo histórico
- Puntuación automática basada en comportamiento

#### Contactos (Contactos)
Registro de interacciones durante repartos:
- `clientId`: ID del cliente
- `result`: Resultado ("Venta", "Rechazó", "Pendiente", "Encargó")
- `deliveryId`: ID del reparto

## 🔄 Sistema de Sincronización

### Arquitectura de Sincronización
- **Local Primero**: Todos los datos se almacenan localmente en SQLite
- **Sincronización Selectiva**: Diferentes tipos de datos se sincronizan en hojas separadas
- **Google Sheets**: Almacén remoto para análisis y respaldo

### Hojas de Google Sheets
- **Repartos**: `Repartos!A1:I` - Datos de entregas
- **Ventas**: `Ventas!A1:H` - Registros de ventas
- **Clientes**: `Clientes!A1:W` - Información de clientes

### Tipos de Sincronización
- `SyncType.deliveries`: Sincronizar repartos
- `SyncType.sales`: Sincronizar ventas
- `SyncType.clients`: Sincronizar clientes
- `SyncType.rateClients`: Recalcular puntuaciones de clientes

## 🧠 Sistema de Puntuación de Clientes

### Algoritmo de Puntuación
El sistema calcula automáticamente una puntuación para cada cliente basada en múltiples factores:

#### Factores de Consistencia (35%)
- **Eventos**: Número total de interacciones
- **Moda**: Cantidad más frecuente comprada
- **Kg por Evento**: Promedio de kg por visita

#### Factores de Volumen (35%)
- **Kg Totales**: Volumen total histórico
- **Máximo**: Mayor cantidad comprada en una visita
- **Kg por Semana**: Volumen semanal promedio

#### Factores de Recencia (30%)
- **Ventas por Vuelta**: Frecuencia de compra por reparto
- **Últimas 10**: Participación en los últimos 10 repartos

### Cálculo Final
```
Puntuación = 0.35 × Consistencia + 0.35 × Volumen + 0.30 × Recencia
```

Las puntuaciones se normalizan para comparar clientes equitativamente.

## 🚀 Instalación y Configuración

### Prerrequisitos
- Flutter SDK (versión 3.0+)
- Dart SDK
- Cuenta de Google Cloud con Google Sheets API habilitada
- Credenciales de servicio account en `lib/services/credentials.json`

### Pasos de Instalación
1. **Clonar el repositorio**
   ```bash
   git clone <repository-url>
   cd prueba_limones
   ```

2. **Instalar dependencias**
   ```bash
   flutter pub get
   ```

3. **Generar código de base de datos**
   ```bash
   flutter pub run build_runner build
   ```

4. **Configurar credenciales de Google**
   - Crear un proyecto en Google Cloud Console
   - Habilitar Google Sheets API
   - Crear una Service Account y descargar las credenciales
   - Colocar el archivo JSON en `lib/services/credentials.json`

5. **Configurar ID de Spreadsheet**
   - Actualizar `_spreadsheetId` en `sync_service.dart` con tu ID de Google Sheet

6. **Ejecutar la aplicación**
   ```bash
   flutter run
   ```

## 📱 Uso de la Aplicación

### Flujo Principal
1. **Configurar Precio Sugerido**: Establecer precio base en la pantalla principal
2. **Iniciar Reparto**: Comenzar un nuevo reparto con temporizador
3. **Visitar Clientes**: Marcar interacciones y registrar ventas
4. **Finalizar Reparto**: Guardar datos del reparto completado
5. **Sincronizar**: Enviar datos a Google Sheets periódicamente

### Pantallas Principales
- **Inicio**: Configuración de precio y navegación principal
- **Reparto**: Gestión activa de entregas con mapa de clientes
- **Ventas**: Registro manual de ventas
- **Clientes**: CRUD completo de base de datos de clientes
- **Sincronización**: Interfaz para operaciones de nube
- **Logs**: Monitoreo de actividades del sistema

## 🔧 Desarrollo

### Agregar Nuevas Características
1. **Modelos de Datos**: Actualizar `database.dart` y regenerar con `build_runner`
2. **Servicios**: Implementar lógica en la capa de servicios
3. **UI**: Crear nuevas páginas siguiendo el patrón existente
4. **Sincronización**: Actualizar rangos de Google Sheets según necesidad

### Comandos Útiles
```bash
# Generar código de base de datos
flutter pub run build_runner build

# Ejecutar tests
flutter test

# Formatear código
flutter format .

# Analizar código
flutter analyze
```

## 📈 Métricas y KPIs

La aplicación calcula automáticamente varias métricas clave:
- **Eficiencia de Reparto**: Tiempo por cliente contactado
- **Tasa de Conversión**: Porcentaje de contactos que resultan en ventas
- **Volumen por Ruta**: Kg entregados por reparto
- **Frecuencia de Cliente**: Promedio de visitas por cliente

## 🔮 Desarrollo Futuro

### Características Planificadas
- [ ] **Registro de Gastos**: Seguimiento completo de costos operativos
- [ ] **Análisis Avanzado**: Dashboards con gráficos y tendencias
- [ ] **Notificaciones**: Recordatorios de visitas y alertas de stock
- [ ] **Rutas Optimizadas**: Integración con mapas para rutas eficientes
- [ ] **Códigos QR**: Lectura rápida de información de clientes
- [ ] **Modo Offline Mejorado**: Sincronización inteligente cuando hay conectividad

### Mejoras Técnicas
- [ ] **Testing Completo**: Cobertura de tests unitarios e integración
- [ ] **CI/CD**: Pipeline automatizado de construcción y despliegue
- [ ] **Documentación API**: Documentación técnica detallada
- [ ] **Internacionalización**: Soporte multiidioma

## 📄 Licencia

Este proyecto es privado y confidencial.

## 👥 Contribución

Para contribuir al proyecto:
1. Crear una rama feature desde `main`
2. Implementar cambios siguiendo las convenciones de código
3. Crear PR con descripción detallada
4. Esperar revisión y aprobación

## 📞 Soporte

Para soporte técnico o preguntas sobre el desarrollo, contactar al equipo de desarrollo.

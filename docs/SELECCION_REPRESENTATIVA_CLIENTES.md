# Selección representativa de clientes — implementación

## Comportamiento

- Catálogo completo del vendedor; no usa el top-200 ni exige tres ventas.
- Snapshot transaccional de clientes, ventas, repartos e interacciones.
- Calcula la prioridad desde ventas reales en cada carga. Los scores importados o atrasados no deciden quién entra.
- Agrupa compras por día para estimar ciclos con los últimos diez días de compra. Intervalos superiores a tres veces la mediana no inflan el promedio, pero sí reducen la confianza.
- Confianza según cantidad y variabilidad de intervalos. Una compra no establece patrón; dos días de compra aportan como máximo 0.25 de confianza.
- Penalización gradual de compra demasiado reciente, sin exclusión rígida al 80% del ciclo.
- Actividad y volumen de los últimos 90 días, con decaimiento exponencial de 45 días. Prioridad base: 45% disposición temporal, 35% actividad, 20% volumen. Escalas fijas de saturación: 3 eventos ponderados y 100 kg ponderados. Refuerzo semanal máximo del 10%, con distancia circular domingo/lunes.
- Inactividad relativa al ciclo: reactivación si han pasado más de max(30 días, 3 ciclos). La falta de contacto no se interpreta como rechazo.
- Selección: 48 mejores candidatos no inactivos, hasta 9 seguimientos adicionales (uno o dos días de compra y última compra hace como máximo 30 días) y hasta 3 reactivaciones garantizadas. Los cupos libres vuelven primero a candidatos activos y, si éstos ya no alcanzan, se completan con más reactivaciones por score. El orden visible final es por score con desempate por ID.
- Reactivación: 14 días entre contactos registrados; se prioriza a quien lleva más tiempo sin intento. Una simple sugerencia no cuenta como contacto, por lo que puede repetirse si no se atiende.
- Cualquier venta o interacción del reparto activo excluye al cliente, en todos los grupos.
- La lista se completa hasta 60 sólo con candidatos de compras válidas (activos, seguimientos y reactivaciones): nunca se inventan visitas. Si el catálogo con compras válidas no alcanza 60, la lista queda más corta. Los clientes sin compras válidas siguen en el catálogo/búsqueda, pero no entran en estas recomendaciones.
- Motivos visibles: Recompra próxima, Seguimiento inicial, Reactivación y Actividad reciente.

## Consistencia

El recálculo individual y general usan ClientPurchaseMetrics, igual que la lista. Las métricas se escriben juntas por cliente; los recálculos se serializan. Se limpian valores antiguos si ya no existen ventas válidas. Se preserva `eventos` como conteo de registros de venta; la confianza y kgEvento usan días de compra distintos.

Las listas regeneradas contienen pendientes: no se reutilizan estados por índice. Se espera la escritura de una interacción antes de recargar. También se recarga al regresar del formulario de venta por búsqueda. No cambia el esquema ni requiere migración.

## Validación y límites

Pruebas con reloj fijo, Drift en memoria (304 clientes), selección real mediante DeliveryService, igualdad entre recálculos individual/general, limpieza de métricas y widget de motivos. Son pruebas de comportamiento, no una medición de precisión comercial con datos reales.

Los parámetros son iniciales. La prioridad no es una probabilidad de venta. Evaluar cobertura de compradores y conversión entre clientes realmente contactados antes de ajustar pesos. No hay aprendizaje automático, registro de impresiones, estacionalidad ni optimización geográfica.

La prueba de ejemplo preexistente `test/widget_test.dart` busca un contador que la aplicación no muestra; falla independientemente de esta funcionalidad. Se conserva sin modificar.

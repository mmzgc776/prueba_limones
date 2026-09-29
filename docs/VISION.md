# Visión: lo que se quiere y todavía no existe

> **Tipo:** requisitos futuros · **Actualizado:** 2026-09-29
> Aquí sólo entran requisitos **confirmados por el dueño del producto** o ideas marcadas explícitamente como "por decidir". Los defectos y mejoras de lo que ya existe van en `PLAN_MEJORAS.md`.

## Confirmados

### V-PIN: PIN local por vendedor
- **Qué:** al elegir el vendedor (o al abrir la app, si se configura) se pide un PIN corto, guardado en el dispositivo.
- **Alcance:** sólo local. Sin JWT, sin servidor y sin recuperación en línea.
- **Por qué:** evita escribir como otro vendedor por error cuando varios comparten el dispositivo, y complementa la corrección de V7 (`currentSellerId` = 1 sin sesión).
- **Pendiente de definir:**
  - dónde vive el PIN: la hoja `Usuarios` o sólo el dispositivo;
  - si se pide en cada arranque o sólo al cambiar de vendedor;
  - qué pasa si se olvida.

## Por decidir (no comprometidos)

| Idea | Contexto |
|---|---|
| Visibilidad mixta entre vendedores | Hoy los datos están aislados por vendedor. Con 2 o 3 vendedores podría servir saber que otro ya visitó o le vendió hoy a un cliente compartido. Sólo tiene sentido si los clientes llegan a compartirse, porque hoy cada cliente pertenece a un vendedor. |
| Sincronización automática con indicador de cambios pendientes | Ya está como mejora #8 en `PLAN_MEJORAS.md`; necesita rastrear cambios (migración). |
| Métricas de negocio (conversión, tiempo por cliente, kg por hora) | La spec original las listaba como KPIs; hoy no se calculan. B1-B4 hacen poco confiable la duración de los repartos. |
| Mejoras a la heurística | Aprendizaje de pesos, registro de impresiones (qué se sugirió y no se atendió), estacionalidad y orden geográfico de la ruta. Requieren medir primero la cobertura y la conversión (`SELECCION_CLIENTES.md` § Validación). |
| "Cerca de ti" en la búsqueda | Mejora #11: usar las coordenadas guardadas; debe ser opcional. |
| Del README anterior, sin confirmar | Dashboards con gráficas y tendencias, notificaciones (recordatorios de visita, alertas de stock), rutas optimizadas con mapas, códigos QR de clientes, CI/CD e internacionalización. Se conservan aquí para no perderlos; ninguno está priorizado. |

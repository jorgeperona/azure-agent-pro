ADD — Kitten Space Missions API (dev)

Propósito: Documento de diseño para la API REST "Kitten Space Missions" en entorno dev. Entrega el diseño arquitectónico, decisiones, seguridad, requisitos no funcionales y próximos pasos. Colocar como docs/workshop/kitten-space-missions/solution/ADD.md.
Resumen ejecutivo

Cliente: MeowTech Space Agency.
Objetivo: API REST para CRUD de Misiones y Astronautas felinos, telemetría en tiempo real y health checks.
Entorno: dev, ubicación westeurope.
Presupuesto objetivo (dev): ~$50–100/mes.
Recursos principales: Azure App Service (App), Azure SQL Database (SQL), Azure Key Vault, Application Insights, Virtual Network + Private Endpoint para SQL, Managed Identity, Log Analytics.
Requisitos clave

Funcionales: CRUD Misiones, CRUD Astronautas, Telemetría realtime, Health checks (liveness/readiness), autenticación al SQL via Managed Identity.
No funcionales: p95 latency < 200 ms, Availability ~99% (dev), HTTPS-only (TLS 1.2+), logging completo en Log Analytics, auto-scaling 1–3 instancias.
Restricciones: Coste limitado, no geo-redundancia, IaC en Bicep modular.
Visión de la arquitectura (alto nivel)

Componentes:
App Service Plan (Básico) + App Service (API).
Azure SQL Server + Azure SQL Database (Basic).
Key Vault (secrets, connection strings opcionales, certs).
Managed Identity (asignada al App Service).
Virtual Network con subnet para Private Endpoint de SQL.
Private Endpoint para SQL (asegura tráfico privado).
Application Insights + Log Analytics Workspace.
(Opcional para realtime) Azure SignalR Service o WebSockets en App Service.
Flujos:
Cliente → HTTPS → App Service (API).
App Service outbound → VNet Integration → Private Endpoint → Azure SQL.
App Service obtiene secretos/keys desde Key Vault mediante Managed Identity (si guarda algún secreto).
Telemetría → Application Insights (instrumentation) y logs/metrics a Log Analytics.
Diagrama ASCII (resumen)

Internet
    |
    v
[Client/App] --HTTPS--> [App Service (app-kitten-missions-dev)]
    | (Managed Identity)
    |--VNet Integration--> [Private Endpoint]
    |
    v
[Azure SQL (sql-kitten-missions-dev)]
App Service --> App Insights & Logs --> [Application Insights] -> [Log Analytics]

Naming conventions

    Resource group: rg-kitten-missions-dev
    App Service plan: asp-kitten-missions-dev
    App Service: app-kitten-missions-dev
    SQL server: sqlsrv-kitten-missions-dev
    SQL database: sql-kitten-missions-dev
    Key Vault: kv-kitten-missions-dev
    VNet: vnet-kitten-missions-dev
    Subnet SQL: snet-sql-private
    Private Endpoint: pe-sql-kitten-missions-dev
    Managed Identity: mi-app-kitten-missions-dev
    Log Analytics: law-kitten-missions-dev
    Application Insights: ai-kitten-missions-dev
    Red de comunicaciones y seguridad de red

VNet: crear VNet regional en westeurope, con al menos:
Subnet pública para recursos que la requieran (si aplica).
Subnet privada para Private Endpoint de SQL (snet-sql-private).
Private Endpoint para Azure SQL: fuerza acceso privado, elimina exposiciones públicas.
App Service: usar Regional VNet Integration (salida desde App→Private Endpoint sobre la VNet) para que las conexiones a SQL vayan por la ruta privada.
NSG: aplicar NSG a subnets si hay recursos PaaS colocados en máquinas virtuales (para Private Endpoint, NSG no es siempre necesario, documentar reglas mínimas si se usan VMs).
Restricciones de acceso a App Service: habilitar "HTTPS Only"; usar App Service Access Restrictions (allow list si es necesario).
TLS: forzar mínimo TLS 1.2 en App Service y Key Vault.
Autenticación y gestión de secretos

Managed Identity: asignar System-Assigned MI al app-kitten-missions-dev.
Azure AD authentication to SQL: habilitar Azure AD Admin en SQL Server; en la DB crear usuario contenido para la MI:
CREATE USER [mi-app-kitten-missions-dev] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [mi-app-kitten-missions-dev]; y permisos de escritura según necesidad.
Key Vault: almacenar certificados o secretos no gestionables por MI; dar acceso a la MI mediante RBAC (Key Vault Secrets User) o policies limitadas; habilitar soft-delete y purge protection (aunque dev puede tener retención corta).
No secrets in code: todo acceso a credenciales vía MI o Key Vault.
Telemetría realtime (diseño)

Opciones:
Uso de WebSockets nativo en App Service para endpoints de telemetría realtime (simple, sin coste adicional).
Recomendado: Azure SignalR Service (Serverless, dev tier gratuito/estándar) si se necesita escalado de conexiones y baja latencia. SignalR se integra con App Service y puede enrutar mensajes realtime a clientes.
Datos persistentes de telemetría: escribir un stream de eventos a una tabla en SQL o (mejor para escala) a Event Hubs / Azure Storage — para dev se puede guardar a SQL.
Observabilidad y logging

Application Insights: instrumentación de API, dependencias, custom metrics (telemetry p95, error rate).
Log Analytics: centralizar logs y consultas KQL; enrutar AI logs a Log Analytics si se desea.
Health checks:
Endpoint /health/live (liveness): verifica que la app está corriendo.
Endpoint /health/ready (readiness): verifica conexión a SQL y Key Vault.
Configurar Probes en App Service/Load Balancer si aplica.
Alerting: alertas básicas en AI/Log Analytics para:
P95 latency > 200 ms.
Error rate > threshold.
CPU/memory alta.
SQL connection failures.
Live Metrics para debugging en dev.
Escalado y rendimiento

App Service Plan: Basic tier con autoscale 1–3 instancias (scale-out rules por CPU o por metric requests).
SQL: Basic tier (DTU) — confirmar que carga de dev cabe en Basic; si pruebas muestran latencia, mover a Standard.
Caching: para performance p95 consider cache local (in-memory) o Azure Cache for Redis — opción a añadir si la App requiere mejorar latencias repetidas.
CDN: no necesario para API pura.
Persistencia y modelo de datos (alto nivel)

Tablas principales:
Missions (id, name, launchDate, status, crewIds JSON/ref, telemetryLastSeen, createdAt, updatedAt)
Astronauts (id, name, species, rank, missionsHistory JSON, createdAt, updatedAt)
Telemetry (missionId, timestamp, metricType, payload JSON) — si alto volumen, evaluar Event Hubs + store.
Indices: indexar por missionId, timestamp para telemetría queries.
Retention: telemetría histórica en SQL por dev; establecer políticas de limpieza.
IaC: Estructura Bicep (modular)

Archivos y módulos sugeridos:
bicep/main.bicep — orchestration que referencia módulos.
bicep/modules/vnet.bicep
bicep/modules/privateEndpoint.bicep
bicep/modules/sql-server.bicep
bicep/modules/sql-database.bicep
bicep/modules/appservice-plan.bicep
bicep/modules/appservice.bicep
bicep/modules/key-vault.bicep
bicep/modules/managedIdentity.bicep
bicep/modules/app-insights.bicep
bicep/modules/log-analytics.bicep
bicep/parameters/dev.parameters.json (parámetros para dev)
Parámetros:
location, sku tiers, instance counts (min/max), admin UPN or azureADAdmin (para SQL), namingPrefix, retentionDays LogAnalytics.
Outputs: app endpoint URL, SQL connection strings (no secreting raw passwords — usar Key Vault), managedIdentity principalId.
Deploy & permisos previos

Pre-reqs:
Azure subscription ID (el usuario lo proporcionará).
Permisos para crear recursos (Owner o Contributor) y asignar roles/Mi.
Habilitar Azure AD admin en SQL (requiere un usuario con permisos).
Flujo de despliegue (dev):
Crear RG rg-kitten-missions-dev.
Desplegar bicep/main.bicep con parámetros dev.
Esperar creación de VNet, Private Endpoint, SQL, Key Vault, App Service.
Configurar Azure AD admin y crear usuario contenido en DB, otorgar permisos a MI.
Desplegar artefacto de la API al app-kitten-missions-dev.
Validar health checks, telemetría y alertas.
Costes (resumen preliminar, estimado dev)

App Service (B1 Basic): pequeño coste mensual (~$10–20).
SQL Database (Basic): ~ $5–15 (dependiendo DTU/vCore).
Key Vault: ~ $2–5 (operaciones mínimas).
Application Insights: ingest variable; con baja carga ~ $5–15.
Log Analytics: ingestion retention controlada; para dev pequeño ~ $5–20.
Otros: Private Endpoint (costo de network interface pequeño), Managed Identity gratis.
Total estimado: ~ $30–80/mes (dependiendo ingest Telemetry y escala). (Se entregará tabla detallada con SKUs y estimaciones en el siguiente artefacto).
Seguridad (resumen y checklist inicial)

Encriptación: TLS 1.2+ enforced; Transparent Data Encryption (TDE) en SQL (activado por defecto).
Network: Private Endpoint para SQL; bloquear acceso público al SQL Server (deny public access).
Identity: usar Managed Identity; no embebas contraseñas en appsettings.
Key Vault: enable soft-delete & purge protection (dev: evaluar purge); RBAC o Access Policies limitadas.
Auditing: habilitar SQL Auditing y Diagnostics sink a Log Analytics.
Logging & Monitoring: habilitar diagnostic settings para enviar logs a Log Analytics.
Least Privilege: asignar solo permisos mínimos a MI en la DB; revisiones periódicas.
DevOps secrets: usar Key Vault para CI/CD secrets e integrarlo con pipeline (Azure DevOps/GitHub Actions).
Backup: habilitar backup básico en SQL (retención mínima dev) y probar restore.
SQL Vulnerability Assessment: habilitar y revisar findings.
Operaciones y Runbook mínimo

Checks diarios: App Health, SQL connectivity, ingestion Anomalies.
Incidentes: cómo escalar si App Service CPU>85% o SQL DTU/vCore saturado.
Backups: pasos para restore DB desde portal o az sql db restore.
Patching: PaaS-managed — validar ventanas de mantenimiento.
Riesgos y mitigaciones

Riesgo: SQL Basic no escala con carga de telemetría → Mitigación: si telemetría crece, cambiar a Standard/vCore o añadir Event Hubs + storage.
Riesgo: Exposición pública accidental de SQL → Mitigación: Private Endpoint + firewall rules + automation checks.
Riesgo: Costes de ingestion logs → Mitigación: ajustar sampling en App Insights, retention y export policies.
Próximos entregables (si apruebas)

Diagrama de arquitectura detallado (ASCII + Mermaid).
Tabla de recursos con SKUs y estimación de costes desglosada.
Checklist de seguridad aplicable y acciones remediantes.
Recomendaciones Well-Architected por pilar con prioridades.
Decisiones abiertas / preguntas para ti

¿Confirmas Subscription ID o prefieres que use un placeholder en IaC?
¿Quieres SignalR Service para telemetría realtime o usar WebSockets nativos en App Service?
¿Retención de logs en Log Analytics (días) objetivo para dev? (sugerido 30 días)
# Proxy
Pass thru proxy with front-end. 

# UI Test Acceleration Tool

## 1. Purpose
- **Accelerate repetitive UI testing** that calls the Ballast API with cruises or hotels.
- **Reduce the frustration** of waiting for slow responses by enabling rapid iteration and feedback.

## 2. Front-End CPL (Control Panel) Features
- **Table with clickable rows** to view detailed API responses.
- **Editable response viewer/editor** with live reflection on remote UI.
- **Modified indicator** to show unsaved or changed responses.
- **Search functionality** to filter rows matching response text.
- **WebSocket connection** to backend for real-time updates as requests flow through the proxy.
- **UTF-8 support** across interface and stored responses.

## 3. Back-End
- Uses **YAML configuration** to define ports and service paths.
- **Single Docker image** deployed with Docker Compose.
- Full **UTF-8 support** for data handling.

## 4. Future Plans
- **No current motivation** to expand support beyond existing Ballast endpoints.
- If additional APIs are added, it will be via YAML configuration per-URL, with **optional gzip compression support**.
- **Low priority** feature expansion.

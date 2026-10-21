# App móvil

App en Flutter para Android e iOS. Funciona sin señal: guarda en el celular y sincroniza con el backend cuando vuelve la conexión.

## Capas

| Carpeta | Qué tiene |
| --- | --- |
| `lib/dominio/` | Modelos y cálculos en Dart puro (edad, etapa, postura, alerta de baja postura, fecha de la granja). Los mismos resultados que el backend |
| `lib/datos/` | Cliente de la API (`api_granja.dart`), que traduce las respuestas a errores claros: sin conexión, registro en conflicto, datos rechazados o error del servidor. Falta la base local SQLite y la cola de sincronización |
| `lib/presentacion/` | Pantallas, widgets y el tema visual |

El dominio no puede importar Flutter ni las otras capas: `test/arquitectura_test.dart` lo revisa.

## Correr

```bash
cd app
flutter pub get
flutter run          # con un celular conectado por USB o un emulador
flutter test         # pruebas
flutter analyze      # lint
dart format lib test # formato
```

En Windows se desarrolla y prueba en Android. Para iOS hace falta un Mac con Xcode.

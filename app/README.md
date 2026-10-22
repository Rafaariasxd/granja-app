# App móvil

App en Flutter para Android e iOS. Funciona sin señal: guarda en el celular y sincroniza con el backend cuando vuelve la conexión.

## Capas

| Carpeta | Qué tiene |
| --- | --- |
| `lib/dominio/` | Modelos y cálculos en Dart puro (edad, etapa, postura, alerta de baja postura, fecha de la granja, id de cada registro). Los mismos resultados que el backend |
| `lib/datos/` | Cliente de la API (`api_granja.dart`), cola de sincronización (`cola.dart`, `sincronizador.dart`), último resumen para verlo sin señal (`resumen.dart`) y la base SQLite del celular con las dos tablas (`base_local.dart`, `almacen_sqlite.dart`) |
| `lib/presentacion/` | Tema visual, lógica del formulario de registro (`formulario_registro.dart`) y pantallas. Las pantallas del boceto se arman cuando se apruebe el diseño |

El dominio no puede importar Flutter ni las otras capas, y los datos no pueden importar la presentación: `test/arquitectura_test.dart` lo revisa.

## Cómo se sincroniza

Cada registro del día entra primero a la cola del celular, con el id que genera el celular y la hora en que se guardó. El sincronizador envía los pendientes en orden:

| Respuesta del servidor | Qué pasa con el registro |
| --- | --- |
| Guardado | Queda enviado |
| Sin señal o error del servidor | Sigue pendiente y se para el envío hasta el próximo intento |
| Conflicto (ya hay otro registro de ese galpón ese día) | Queda marcado con el mensaje para mostrárselo a quien registró. No se reintenta ni se pisa nada |
| Datos rechazados (por ejemplo, galpón sin lote ese día) | Queda marcado con el mensaje y se siguen enviando los demás |

Corregir un registro antes de enviarlo lo reemplaza en la cola. Corregirlo después de enviado lo vuelve a enviar, y el servidor lo actualiza porque el id es el mismo.

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

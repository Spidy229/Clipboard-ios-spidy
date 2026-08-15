# Super Portapapeles

Aplicación privada de historial del portapapeles para iPhone y iPad.

## Compilación

GitHub Actions genera `Super-Portapapeles-unsigned.ipa` en un runner macOS. La IPA no contiene una firma de Apple y debe firmarse después con KravaSign, Feather o una herramienta equivalente usando el certificado y el perfil asociados al UDID del dispositivo.

El código de la aplicación está en `SuperPortapapelesV2/`. `project.yml` genera el proyecto Xcode reproducible mediante XcodeGen.


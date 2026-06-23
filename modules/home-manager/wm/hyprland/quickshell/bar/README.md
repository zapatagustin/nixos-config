# Quickshell Bar — Gruvbox + Hyprland

Barra de estado estilo DWM para Hyprland con tema Gruvbox dinámico.

## Características

- **Workspaces** a la izquierda con numeración japonesa (一 二 三 ...)
- **Título de ventana activa** centrado
- **System tray** + reloj con fecha a la derecha
- **Gruvbox Dark** de noche (20:00 → 07:00), **Gruvbox Light** de día
- Indicador luna/sol (requiere Nerd Fonts)

## Dependencias

```bash
# CachyOS / Arch
sudo pacman -S quickshell noto-fonts-cjk ttf-nerd-fonts-symbols
```

> Asegurate de tener `quickshell` compilado con soporte para:
> - `Quickshell.Hyprland`
> - `Quickshell.Services.SystemTray`

## Instalación

```bash
# 1. Copiar al directorio de configuración
mkdir -p ~/.config/quickshell/bar
cp *.qml ~/.config/quickshell/bar/

# 2. Lanzar (para probar)
quickshell -p ~/.config/quickshell/bar

# 3. Auto-inicio con Hyprland
#    En ~/.config/hypr/hyprland.conf agregar:
exec-once = quickshell -p ~/.config/quickshell/bar
```

## Estructura de archivos

```
~/.config/quickshell/bar/
├── shell.qml          ← Entry point (ShellRoot + tema)
├── Bar.qml            ← Layout principal
├── Workspaces.qml     ← Lógica de workspaces
├── WorkspaceButton.qml← Botón individual
├── ActiveWindow.qml   ← Título ventana activa
├── RightSection.qml   ← Tray + reloj wrapper
├── TrayIcon.qml       ← Ícono de tray con menú
└── Clock.qml          ← Reloj + fecha
```

## Personalización

### Cambiar horario día/noche

En `shell.qml`, modificar la propiedad `isDark`:
```qml
property bool isDark: {
    var h = new Date().getHours()
    return h >= 20 || h < 7   // ← ajustar estas horas
}
```

### Cambiar cantidad de workspaces

En `Workspaces.qml`, cambiar el `model` del `Repeater`:
```qml
model: 9   // ← cambiar a la cantidad deseada (máx 10 con números japoneses)
```

### Fuente

La barra usa `Noto Sans JP` para el texto y `Symbols Nerd Font Mono`
para los íconos de luna/sol. Si no tenés Nerd Fonts, podés reemplazar
los íconos en `RightSection.qml`:
```qml
text: rightSection.isDark ? "N" : "D"   // fallback sin nerd fonts
```

## Hyprland — configuración recomendada

En `~/.config/hypr/hyprland.conf`:

```ini
# Reservar espacio para la barra (Quickshell lo hace automáticamente
# via exclusiveZone, pero por las dudas):
monitor = ,preferred,auto,1

# Gaps que se ven bien con la barra
general {
    gaps_in = 4
    gaps_out = 6
    border_size = 2
    col.active_border = rgba(d79921ff)    # Gruvbox yellow
    col.inactive_border = rgba(504945ff) # Gruvbox bg2
}
```

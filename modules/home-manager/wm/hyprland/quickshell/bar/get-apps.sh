#!/bin/bash
# Genera lista de apps instaladas desde .desktop files
# Formato: "Nombre\tcomando"
# Solo lee la seccion [Desktop Entry], igual que dmenu_run

# Recorre los applications/ de cada entrada de XDG_DATA_DIRS (en NixOS los
# .desktop viven en /etc/profiles/.../share/applications y
# /run/current-system/sw/share/applications, no en /usr/share/applications).
data_dirs="${XDG_DATA_DIRS:-/usr/share:/usr/local/share}"
dirs=()
IFS=':' read -ra _xdg <<< "$data_dirs"
for base in "$HOME/.local/share" "${_xdg[@]}"; do
    [ -n "$base" ] && dirs+=("$base/applications")
done

for dir in "${dirs[@]}"; do
    [ -d "$dir" ] || continue
    for f in "$dir"/*.desktop; do
        [ -f "$f" ] || continue
        
        # Leer solo la seccion [Desktop Entry]
        in_entry=0
        name=""
        exec=""
        nodisplay=""
        
        while IFS= read -r line; do
            case "$line" in
                "[Desktop Entry]")
                    in_entry=1 ;;
                "["*)
                    in_entry=0 ;;
            esac
            
            [ "$in_entry" -eq 0 ] && continue
            
            case "$line" in
                Name=*)   [ -z "$name" ] && name="${line#Name=}" ;;
                Exec=*)   exec="${line#Exec=}" ;;
                NoDisplay=true) nodisplay=1 ;;
                Hidden=true)    nodisplay=1 ;;
            esac
        done < "$f"
        
        # Limpiar argumentos %u %f etc y marcadores file-forwarding de flatpak (@@u ... @@)
        exec=$(echo "$exec" | sed 's/ %[uUfFdDnNickvm]//g' | sed "s/'%[uUfFdDnNickvm]'//g" \
            | sed 's/ @@u\?//g; s/ @@//g' | xargs)
        
        [ -n "$name" ] && [ -n "$exec" ] && [ -z "$nodisplay" ] && \
            echo -e "$name\t$exec"
    done
done | sort -u -t$'\t' -k1,1 | awk -F'\t' '!seen[$1]++'

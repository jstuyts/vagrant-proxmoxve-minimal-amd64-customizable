Remove-Item *.box -Force -ErrorAction SilentlyContinue
Remove-Item iso\custom.iso -Force -ErrorAction SilentlyContinue
Remove-Item build -Recurse -Force -ErrorAction SilentlyContinue

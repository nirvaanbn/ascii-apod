package main

import(
	"embed"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
)

//go:embed ascii-wallpaper
var pluginFiles embed.FS

// installs ascii plug-in, if not on your machine already
func installPlugin(home string) error {
	mine := filepath.Join(home, ".local", "share", "plasma", "wallpapers", plugin)
	system := filepath.Join("/usr", "share", "plasma", "wallpapers", plugin)
	for _, dir := range []string{mine, system}{
		if _, err := os.Stat(dir); err == nil {
			return nil
		}
	}
	files, err := fs.Sub(pluginFiles, "ascii-wallpaper")
	if err != nil {
		return err
	}
	if err := os.CopyFS(mine, files); err != nil {
		return fmt.Errorf("plugin: %v", err)
	}
	return nil
}
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

const plugin = "de.korvexx.ascii_wallpaper"

func setLockScreen(file string) error {
	err := kwrite("WallpaperPlugin", plugin, "Greeter")
	if err != nil {
		return err
	}
	return kwrite ("Images", file, "Greeter", "Wallpaper", plugin, "Wallpaper")
}

func kwrite(key, value string, groups ...string) error {
	args := []string{"--file", "kscreenlockerrc"}
	for _, g := range groups {
		args = append(args, "--group", g)
	}
	args = append(args, "--key", key, value)
	cmd := exec.Command("kwriteconfig6", args...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("lock screen: %v: %s", err, out)
	}
	return nil
}

func cleanup(dir, keep string) error {
	old, err := filepath.Glob(filepath.Join(dir, "apod-*"))
	if err != nil {
		return err
	}
	for _, f := range old {
		if f != keep {
			if err := os.Remove(f); err != nil {
				return err
			}
		}
	}
	return nil
}
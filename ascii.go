package main

import (
	_ "embed"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

//go:embed ascii.py
var asciiPy string

func saveASCII(photo, dir string) error {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	name := strings.TrimSuffix(filepath.Base(photo), filepath.Ext(photo)) + ".png"
	cmd := exec.Command("python3", "-I", "-c", asciiPy, photo, filepath.Join(dir, name))
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("ascii: %v: %s", err, out)
	}
	return nil
}

// new function for saving the current ascii-apod

func saveCurrent(dir string) error {
	cmd := exec.Command("kreadconfig6", "--file", "kscreenlockerrc","--group", "Greeter", "--group", "Wallpaper", "--group", plugin, "--group", "Wallpaper", "--key", "Images")
	
	out, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("ascii: %v", err)
	}
	photo := strings.TrimSpace(string(out))
	if photo == "" {
		return fmt.Errorf("nothing to save yet. run the program once to set your lock screen, then try again")
	}
	return saveASCII(photo, dir)
}
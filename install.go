package main

import(
	"embed"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

//go:embed units
var unitFiles embed.FS

// grabbing from the units folder
var unitNames = []string{"apod.service", "apod.timer"}

func install(home string) error {
	self, err := os.Executable()
	if err != nil {
		return err
	}
	bin := filepath.Join(home, ".local", "bin", "apod")
	if self != bin {
		if err := copyFile(self, bin); err != nil {
			return fmt.Errorf("install %v", err)
		}
	}
	units := filepath.Join(home, ".config", "systemd", "user")
	if err := os.MkdirAll(units, 0o755); err != nil {
		return err
	}
	for _, name := range unitNames {
		data, err := unitFiles.ReadFile("units/" + name)
		if err != nil {
			return err
		}
		if err := os.WriteFile(filepath.Join(units, name), data, 0o644); err != nil {
			return fmt.Errorf("install: %v", err)
		}
	}
	if err := systemctl("daemon-reload"); err != nil {
		return err
	}
	return systemctl("start", "--no-block", "apod.service")
}

// auto switches the timer to update on/off

func auto(home string, on bool) error {
	timer := filepath.Join(home, ".config", "systemd", "user", "apod.timer")
	if _, err := os.Stat(timer); err != nil {
		return fmt.Errorf("auto: run apod install first")
	}
	if on {
		return systemctl("enable", "--now", "apod.timer")
	}
	return systemctl("disable", "--now", "apod.timer")
}
func uninstall(home string) error {
	units := filepath.Join(home, ".config", "systemd", "user")
	if _, err := os.Stat(filepath.Join(units, "apod.timer")); err == nil {
		if err := systemctl("disable", "--now", "apod.timer"); err != nil {
			return err
		}
	}
	for _, name := range unitNames{
		if err := os.RemoveAll(filepath.Join(units, name)); err != nil {
			return err
		}
	}
	if err := systemctl("daemon-reload"); err != nil {
		return err
	}
	return os.RemoveAll(filepath.Join(home, ".local", "bin", "apod"))
}


func copyFile(from, to string) error {
	data, err := os.ReadFile(from)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(to), 0o755); err != nil {
		return err
	}
	if err := os.WriteFile(to+".part", data, 0o755); err != nil {
		return err
	}
	return os.Rename(to+".part", to)
}

// running all the systemctl args

func systemctl(args ...string) error {
	cmd := exec.Command("systemctl", append([]string{"--user"}, args...)...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("systemctl %v: %v: %s", args, err, out)
	}
	return nil
}
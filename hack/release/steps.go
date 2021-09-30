/*
Copyright 2021 The Cockroach Authors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
package main

import (
	"bytes"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"regexp"
	"strings"
)

var (
	versionRegxp = regexp.MustCompile(`^\d+\.\d+\.\d+(-beta\.\d+)?$`)
)

// Step defines an action to be taken during the release process
type Step interface {
	Apply(version string) error
}

// StepFn is a function that implements Step.
type StepFn func(version string) error

// Apply applies the function.
func (fn StepFn) Apply(version string) error {
	return fn(version)
}

// CmdFn describes a function that runs a Cmd.
type CmdFn func(cmd *exec.Cmd) error

// ExecFn describes a function that executes shell commands.
type ExecFn func(cmd string, args, env []string) error

// ValidateVersion ensures the supplied version matches our expected version regexp.
func ValidateVersion() Step {
	return StepFn(func(version string) error {
		if !versionRegxp.MatchString(version) {
			return fmt.Errorf("invalid version '%s'. Must be of the form N.N.N(-beta.N)", version)
		}

		return nil
	})
}

// EnsureUniqueVersion verifies that this is a new version by checking the existing tags.
func EnsureUniqueVersion(fn CmdFn) Step {
	return StepFn(func(version string) error {
		stdout := new(bytes.Buffer)
		stderr := new(bytes.Buffer)

		cmd := exec.Command("git", "tag")
		cmd.Stdout = stdout
		cmd.Stderr = stderr
		if err := fn(cmd); err != nil {
			return fmt.Errorf("failed to get tags: %s - %s", string(stderr.Bytes()), err)
		}

		for _, v := range strings.Split(string(stdout.Bytes()), "\n") {
			if v == "" {
				continue
			}

			// tags have a `v` prefix, so we remove it for comparison
			if v[1:] == version {
				return fmt.Errorf("version already exists")
			}
		}

		return nil
	})
}

// UpdateVersion sets the version in version.txt
func UpdateVersion() Step {
	return StepFn(func(version string) error {
		// setting the mode to 0644 to match the existing permissions: r/w for current user, read-only for everyone else.
		return ioutil.WriteFile("version.txt", []byte(version), 0644)
	})
}

// CreateReleaseBranch creates a new branch for the release named release-<version>.
func CreateReleaseBranch(fn ExecFn) Step {
	return StepFn(func(version string) error {
		return fn(
			"git",
			[]string{"checkout", "-b", fmt.Sprintf("release-%s", version), "origin/master"},
			os.Environ(),
		)
	})
}

// GenerateFiles runs make release/gen-files passing the appropriate channel options based on the version.
func GenerateFiles(fn ExecFn) Step {
	return StepFn(func(version string) error {
		ch := "stable"
		isDefault := "1"

		if strings.Contains(version, "-beta") {
			ch = "beta"
			isDefault = "0"
		}

		return fn(
			"make",
			[]string{"release/gen-files", "CHANNEL=" + ch, "IS_DEFAULT_CHANNEL=" + isDefault},
			os.Environ(),
		)
	})
}
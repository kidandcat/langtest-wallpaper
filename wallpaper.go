package main

import (
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"os"
	"os/exec"
	"strings"
)

func main() {
	n := rand.Intn(77)
	req, err := http.NewRequest(
		"GET",
		fmt.Sprintf("https://konachan.net/post?tags=landscape&page=%d", n),
		nil,
	)
	if err != nil {
		panic(err)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		panic(err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		panic(err)
	}
	urls := getAllURLs(string(body))

	n2 := rand.Intn(len(urls))

	req2, err := http.NewRequest(
		"GET",
		urls[n2],
		nil,
	)
	if err != nil {
		panic(err)
	}
	resp2, err := http.DefaultClient.Do(req2)
	if err != nil {
		panic(err)
	}
	defer resp2.Body.Close()

	// Clear previous images using os package
	files, err := os.ReadDir(".")
	if err != nil {
		panic(err)
	}
	for _, file := range files {
		if strings.Contains(file.Name(), ".jpg") {
			err := os.Remove(file.Name())
			if err != nil {
				panic(err)
			}
		}
	}

	// Save to file with random name
	name := GenName(5) + ".jpg"
	file, err := os.Create(name)
	if err != nil {
		panic(err)
	}
	defer file.Close()
	_, err = io.Copy(file, resp2.Body)
	if err != nil {
		panic(err)
	}

	// Set wallpaper
	_, err = exec.Command(
		"automator",
		"-i",
		name,
		"/Users/jairo/setDesktopPicture.workflow",
	).Output()
	if err != nil {
		panic(err)
	}
}

func getAllURLs(body string) []string {
	var urls []string
	for {
		if !strings.Contains(body, "https://konachan.net/image/") {
			break
		}
		url, rest := getImageUrlAndRest(body)
		urls = append(urls, url)
		body = rest
	}
	return urls
}

func getImageUrlAndRest(body string) (string, string) {
	if !strings.Contains(body, "https://konachan.net/image/") {
		return "", ""
	}
	i1 := strings.Split(body, "https://konachan.net/image/")
	i2 := strings.Split(i1[1], "\"")
	return "https://konachan.net/image/" + i2[0], i2[1]
}

var letters = []rune("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")

func GenName(n int) string {
	b := make([]rune, n)
	for i := range b {
		b[i] = letters[rand.Intn(len(letters))]
	}
	return string(b)
}

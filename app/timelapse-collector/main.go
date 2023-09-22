package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

var (
	interval     = 3 * time.Minute
	url          string
	baseFilename string
)

const (
	timeFormat = "20060102150405"
)

func main() {
	parseFlags()

	log.Printf("interval: %s", interval.String())
	log.Printf("baseFilename: %s", baseFilename)

	capture()
	ticker := time.NewTicker(interval)

	for {
		select {
		case <-ticker.C:
			capture()
		}
	}
}

func parseFlags() {
	flag.DurationVar(&interval, "interval", time.Minute*3, "time interval (default 3m)")
	flag.StringVar(&baseFilename, "baseFilename", "image_%s.jpeg", "base filename, with %s for where the UTC time goes")
	flag.StringVar(&url, "url", "", "URL to fetch from")
	flag.Parse()
	if url == "" {
		log.Printf("Error: must specify a URL")
		os.Exit(1)
	}
}

func capture() {
	filename := fmt.Sprintf(baseFilename, time.Now().UTC().Format(timeFormat))
	log.Printf("Capturing image to %s", filename)

	resp, err := http.Get(url)
	if err != nil {
		log.Printf("fetch error: %v", err)
		return
	}
	defer resp.Body.Close()
	image, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("reading body error: %v", err)
		return
	}
	log.Printf("Fetched image.  Length %d", len(image))

	f, err := os.Create(filename)
	if err != nil {
		log.Printf("cannot open file: %v", err)
		return
	}
	defer func() {
		if f.Close() != nil {
			log.Printf("closing file: %v", err)
		}
	}()
	n, err := f.Write(image)
	if err != nil {
		log.Printf("writing file: %v", err)
		return
	}
	if n != len(image) {
		log.Printf("wrote only %d of %d bytes", n, len(image))
		return
	}
}

package main

import(
	"encoding/xml"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path"
	"time"

)

const feedURL = "https://science.nasa.gov/feed/apod-basic/"

type feed struct {
	Items []item `xml:"channel>item"`
}

type item struct {
	Title string `xml:"title"`
	PubDate string `xml:"pubDate"`
	HDURL string `xml:"hdurl"`
}

var client = &http.Client{Timeout: 1 * time.Minute}

func BestFetchFunc() (item, error) {
	resp, err :=client.Get(feedURL)
	if err != nil {
		return item {}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return item{}, fmt.Errorf("feed: %s", resp.Status)
	}
	var f feed 
	if err := xml.NewDecoder(resp.Body).Decode(&f); err !=nil {
		return item{}, err
	}
	if len(f.Items) == 0 {
		return item{}, fmt.Errorf("no APOD in the feed")

	}
	return f.Items[0], nil
}

func fileName(it item) (string, error) {
	posted, err := time.Parse(time.RFC1123Z, it.PubDate)
	if err !=nil {
		return "that shit got an error:", err
	}
	u, err := url.Parse(it.HDURL)
	if err != nil {
		return "that shit got an errror:", err
	}
	day := posted.UTC().Format("2006-01-02")
	return "apod-" + day + path.Ext(u.Path), nil
}

func download(url, file string) error {
	resp, err := client.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK{
		return fmt.Errorf("picture: %s", resp.Status)
	}
	f, err := os.Create(file + ".part")
	if err != nil {
		return err
	}
	if _, err := io.Copy(f, resp.Body); err != nil {
		f.Close()
		return err
	}
	if err := f.Close(); err != nil {
		return err
	}
	return os.Rename(file+ ".part", file)
} 
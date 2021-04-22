package main

import (
	"bytes"
	"compress/zlib"
	"encoding/base64"
	"errors"
	"io/ioutil"
	"os"
)

func main() {
	name := os.Args[1]

	data, err := ioutil.ReadFile(name + ".json")
	if err != nil {
		panic(err)
	}

	var buf bytes.Buffer
	encoder := zlib.NewWriter(base64.NewEncoder(base64.StdEncoding, &buf))

	var w int
	defer encoder.Close()
	if w, err = encoder.Write(data); err != nil {
		panic(err)
	} else if w != len(data) {
		err = errors.New("not all the bytes were encoded")
		panic(err)
	}

	if err = encoder.Flush(); err != nil {
		panic(err)
	}

	ioutil.WriteFile(name+".state", []byte(buf.String()), 0644)
}

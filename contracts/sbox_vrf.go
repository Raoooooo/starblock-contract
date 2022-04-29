package main

import (
	"crypto/md5"
	"encoding/binary"
	"fmt"
	"io"
	"math/rand"
	"strings"
)

func main() {

	nftWinnerList := []int{}

	// SBOXRandomSeedGenerator: https://etherscan.io/address/0x8a664be336304385b2886e706828e4ee1e549d44#code
	var contractRandomSeed = "63477085376221734204645267060198448640767645553793835987915088287774969511994"
	var nftCount = 14

	// we are converting seed to md5 then int64
	md5Seed := md5.New()
	_, _ = io.WriteString(md5Seed, contractRandomSeed)
	var seed = binary.BigEndian.Uint64(md5Seed.Sum(nil))
	rand.Seed(int64(seed))

	for len(nftWinnerList) < nftCount {
		// get random sbox id between 0, 13
		randBox := randInt(0, 13)
		// add this sbox to winnerList
		if !contains(nftWinnerList, randBox) {
			nftWinnerList = append(nftWinnerList, randBox)
		}
	}

	fmt.Println(strings.Trim(strings.Join(strings.Fields(fmt.Sprint(nftWinnerList)), ","), "[]"))

}

func contains(s []int, i int) bool {
	for _, v := range s {
		if v == i {
			return true
		}
	}
	return false
}

func randInt(min int, max int) int {
	return min + rand.Intn(max-min+1)
}

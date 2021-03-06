package credentials

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestStaticProviderGet(t *testing.T) {
	s := StaticProvider{
		Value: Value{
			AccessKeyId:     "AKID",
			SecretAccessKey: "SECRET",
			SessionToken:    "",
		},
	}

	creds, err := s.Retrieve()
	assert.Nil(t, err, "Expect no error")
	assert.Equal(t, "AKID", creds.AccessKeyId, "Expect access key ID to match")
	assert.Equal(t, "SECRET", creds.SecretAccessKey, "Expect secret access key to match")
	assert.Empty(t, creds.SessionToken, "Expect no session token")
}

func TestStaticProviderIsExpired(t *testing.T) {
	s := StaticProvider{
		Value: Value{
			AccessKeyId:     "AKID",
			SecretAccessKey: "SECRET",
			SessionToken:    "",
		},
	}

	assert.False(t, s.IsExpired(), "Expect static credentials to never expire")
}

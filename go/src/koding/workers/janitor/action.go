package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"koding/db/models"
	"koding/db/mongodb/modelhelper"
	"net"
	"net/http"
	"socialapi/workers/email/emailsender"
	"time"
)

var subjects = map[string]string{
	"vmDeletionWarning-1": "received 1st VM deletion warning",
	"vmDeletionWarning-2": "received 2nd VM deletion warning",
}

type Action func(*models.User, string) error

type requestArgs struct {
	MachineID string `json:"machineId"`
	Provider  string `json:"provider"`
}

func SendEmail(user *models.User, warningID string) error {
	subject, ok := subjects[warningID]
	if !ok {
		subject = "unknown warning"
	}

	account, err := modelhelper.GetAccount(user.Name)
	if err != nil {
		return err
	}

	machines, err := modelhelper.GetMachinesByUsernameAndProvider(user.Name, modelhelper.MachineProviderKoding)
	if err != nil {
		return err
	}

	if len(machines) < 1 {
		return errors.New("user has no vms")
	}

	mail := &emailsender.Mail{
		To:      user.Email,
		Subject: subject,
		Properties: &emailsender.Properties{
			Username: user.Name,
			Options: map[string]interface{}{
				"first_name": account.Profile.FirstName,
				"vm_name":    machines[0].Label,
			},
		},
	}

	return emailsender.Send(mail)
}

func DeleteVMs(user *models.User, _ string) error {
	if j.kiteClient == nil {
		return ErrKloudKlientNotInitialized
	}

	machines, err := modelhelper.GetMachinesByUsername(user.Name)
	if err != nil {
		return err
	}

	var topErr error

	for _, machine := range machines {
		_, err := j.kiteClient.Tell("destroy", &requestArgs{
			MachineID: machine.ObjectId.Hex(),
			Provider:  "koding",
		})

		if err != nil {
			topErr = err
		}
	}

	return topErr
}

var defClient = &http.Client{
	Transport: &http.Transport{
		Dial: func(network, addr string) (net.Conn, error) {
			return net.DialTimeout(network, addr, time.Second*5)
		},
	},
	Timeout: time.Second * 30,
}

type usernameReq struct {
	Username string `json:"username"`
}

// newDeleteUser creates a function that deletes the user from koding
func newDeleteUserFunc(url string) Action {
	return func(user *models.User, _ string) error {
		if user.Name == "" {
			return fmt.Errorf("Username is empty. User -> %+v", user)
		}

		ses, err := modelhelper.CreateSessionForAccount(user.Name, kodingGroupName)
		if err != nil {
			return err
		}

		b, err := json.Marshal(usernameReq{
			Username: user.Name,
		})
		if err != nil {
			return err
		}

		req, err := http.NewRequest("POST", url, bytes.NewReader(b))
		if err != nil {
			return err
		}

		req.AddCookie(&http.Cookie{
			Name:  "clientId",
			Value: ses.ClientId,
		})

		_, err = defClient.Do(req)
		return err
	}
}

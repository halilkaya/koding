package models

import (
	"fmt"
	"time"

	"socialapi/models"

	"github.com/hashicorp/go-multierror"
	"github.com/koding/bongo"
)

// NotificationActivity stores each user NotificationActivity related to notification content.
// When a user makes duplicate NotificationActivity for the same content
// old one is set as obsolete and new one is added to NotificationActivity table
type NotificationActivity struct {
	// unique identifier of NotificationActivity
	Id int64 `json:"id"`

	// notification content foreign key
	NotificationContentId int64 `json:"notificationContentId" sql:"NOT NULL"`

	// message foreign key
	MessageId int64 `json:"messageId,string"`

	// notifier account foreign key
	ActorId int64 `json:"actorId,string" sql:"NOT NULL"`

	// activity creation time
	CreatedAt time.Time `json:"createdAt" sql:"NOT NULL"`

	// activity obsolete information
	Obsolete bool `json:"obsolete" sql:"NOT NULL"`
}

// Create method creates a new activity with obsolete field set as false
// If there already exists one activity with same ActorId and
// NotificationContentId pair, old one is set as obsolete, and
// new one is created
func (a *NotificationActivity) Create() error {
	activity := NewNotificationActivity()
	*activity = *a
	s := map[string]interface{}{
		"notification_content_id": a.NotificationContentId,
		"actor_id":                a.ActorId,
		// "message_id":              a.MessageId,
		"obsolete": false,
	}

	q := bongo.NewQS(s)
	found := true
	if err := activity.One(q); err != nil {
		if err != bongo.RecordNotFound {
			return err
		}
		found = false
	}

	if found {
		if err := bongo.B.Update(activity); err != nil {
			return err
		}
		a.Id = 0
		a.Obsolete = false
	}

	return bongo.B.Create(a)
}

func (a *NotificationActivity) FetchByContentIds(ids []int64) ([]NotificationActivity, error) {
	activities := make([]NotificationActivity, 0)
	err := bongo.B.DB.Table(a.BongoName()).
		Where("notification_content_id IN (?)", ids).
		Order("id asc").
		Find(&activities).Error

	if err != nil {
		return nil, err
	}

	return activities, nil
}

func (a *NotificationActivity) FetchMapByContentIds(ids []int64) (map[int64][]NotificationActivity, error) {
	if len(ids) == 0 {
		return make(map[int64][]NotificationActivity), nil
	}

	aList, err := a.FetchByContentIds(ids)
	if err != nil {
		return nil, err
	}

	aMap := make(map[int64][]NotificationActivity)
	for _, activity := range aList {
		aMap[activity.NotificationContentId] = append(aMap[activity.NotificationContentId], activity)
	}

	return aMap, nil
}

func (a *NotificationActivity) LastActivity() error {
	s := map[string]interface{}{
		"notification_content_id": a.NotificationContentId,
		"obsolete":                false,
	}

	q := bongo.NewQS(s)
	q.Sort = map[string]string{
		"created_at": "DESC",
	}

	return a.One(q)
}

func (a *NotificationActivity) FetchContent() (*NotificationContent, error) {
	if a.NotificationContentId == 0 {
		return nil, fmt.Errorf("NotificationContentId is not set")
	}
	nc := NewNotificationContent()
	if err := nc.ById(a.NotificationContentId); err != nil {
		return nil, err
	}

	if a.MessageId != 0 {
		nc.TargetId = a.MessageId
	}

	return nc, nil
}

// DeleteWithContentId delete the given content id from notification_activity table
func (a *NotificationActivity) DeleteWithContentId(contentIds ...int64) error {

	return a.deleteWithContentId(contentIds...)
}

func (a *NotificationActivity) deleteWithContentId(contentIds ...int64) error {
	// we use error struct for this function because of iterating over all elements
	// and we'r gonna try to delete given ids at least one time..
	var errs *multierror.Error

	if len(contentIds) == 0 {
		return models.ErrIdIsNotSet
	}

	for _, id := range contentIds {
		na := NewNotificationActivity()

		activityIds, err := na.fetchWithContentId(id)
		if err != nil && err != bongo.RecordNotFound {
			errs = multierror.Append(errs, err)
		}

		for _, activityId := range activityIds {
			if err := activityId.Delete(); err != nil {
				if err != bongo.RecordNotFound {
					// return err
					errs = multierror.Append(errs, err)
				}
			}
		}
	}
	return errs.ErrorOrNil()
}

func (a *NotificationActivity) fetchWithContentId(contentId int64) ([]NotificationActivity, error) {
	selector := map[string]interface{}{
		"notification_content_id": contentId,
	}

	var notyActivities []NotificationActivity
	if err := a.Some(&notyActivities, bongo.NewQS(selector)); err != nil {
		return nil, err
	}

	return notyActivities, nil

}

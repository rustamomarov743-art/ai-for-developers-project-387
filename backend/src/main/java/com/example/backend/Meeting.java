package com.example.backend;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.time.Instant;

record Meeting(
    String id,
    String meetingTypeId,
    Instant startsAt,
    Instant endsAt,
    String guestName,
    String guestEmail,
    Instant createdAt,
    MeetingStatus status,
    MeetingType meetingType,
    @JsonInclude(JsonInclude.Include.NON_NULL) String note) {}

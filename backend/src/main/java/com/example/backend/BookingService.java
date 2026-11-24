package com.example.backend;

import static com.example.backend.JsonRequests.isPresent;

import java.time.Instant;
import java.util.ArrayList;

class BookingService {

  private final SlotCalculator slotCalculator;

  BookingService(SlotCalculator slotCalculator) {
    this.slotCalculator = slotCalculator;
  }

  Meeting create(
      CreateBookingRequest request,
      MeetingTypeCatalog meetingTypes,
      AvailabilitySchedule availability,
      MeetingRegistry meetings) {
    var validated = validate(request);
    var meetingType =
        meetingTypes.find(validated.meetingTypeId()).orElseThrow(SlotUnavailableException::new);
    var slot =
        slotCalculator
            .findAvailableSlotInAnyGuestWindow(
                meetingType, availability.current(), validated.startsAt(), meetings.busyIntervals())
            .orElseThrow(SlotUnavailableException::new);
    return meetings.book(
        meetingType, slot, validated.guestName(), validated.guestEmail(), validated.note());
  }

  private static ValidatedBooking validate(CreateBookingRequest request) {
    if ((isPresent(request.meetingTypeId()) && !request.meetingTypeId().isTextual())
        || (isPresent(request.startsAt()) && !request.startsAt().isTextual())
        || (isPresent(request.guestName()) && !request.guestName().isTextual())
        || (isPresent(request.guestEmail()) && !request.guestEmail().isTextual())
        || (isPresent(request.note()) && !request.note().isTextual())) {
      throw new MalformedRequestException();
    }
    var errors = new ArrayList<ApiFieldError>();
    var meetingTypeId =
        isPresent(request.meetingTypeId()) ? request.meetingTypeId().textValue().trim() : "";
    if (meetingTypeId.isEmpty()) {
      errors.add(new ApiFieldError("meetingTypeId", "Тип встречи обязателен"));
    }
    Instant startsAt = null;
    try {
      startsAt =
          Instant.parse(isPresent(request.startsAt()) ? request.startsAt().textValue().trim() : "");
    } catch (RuntimeException exception) {
      errors.add(new ApiFieldError("startsAt", "Укажите начало встречи в формате ISO 8601 UTC"));
    }
    var guestName = isPresent(request.guestName()) ? request.guestName().textValue().trim() : "";
    if (guestName.isEmpty()) {
      errors.add(new ApiFieldError("guestName", "Имя обязательно"));
    } else if (guestName.length() > 100) {
      errors.add(new ApiFieldError("guestName", "Имя должно содержать не более 100 символов"));
    }
    var guestEmail = isPresent(request.guestEmail()) ? request.guestEmail().textValue().trim() : "";
    if (guestEmail.isEmpty()) {
      errors.add(new ApiFieldError("guestEmail", "Email обязателен"));
    } else if (guestEmail.length() > 254) {
      errors.add(new ApiFieldError("guestEmail", "Email должен содержать не более 254 символов"));
    } else if (!isValidEmail(guestEmail)) {
      errors.add(new ApiFieldError("guestEmail", "Укажите корректный email"));
    }
    var note = isPresent(request.note()) ? request.note().textValue().trim() : "";
    if (note.length() > 500) {
      errors.add(new ApiFieldError("note", "Заметка должна содержать не более 500 символов"));
    }
    if (!errors.isEmpty()) {
      throw new RequestValidationException(errors);
    }
    return new ValidatedBooking(
        meetingTypeId, startsAt, guestName, guestEmail, note.isEmpty() ? null : note);
  }

  private static boolean isValidEmail(String email) {
    var at = email.indexOf('@');
    return at > 0
        && at == email.lastIndexOf('@')
        && at < email.length() - 1
        && email.chars().noneMatch(Character::isWhitespace);
  }

  private record ValidatedBooking(
      String meetingTypeId, Instant startsAt, String guestName, String guestEmail, String note) {}
}

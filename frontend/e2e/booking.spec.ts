import { expect, test } from '@playwright/test'
import type { APIRequestContext } from '@playwright/test'

const workInterval = [{ start: '09:00', end: '18:00' }]
const weeklyTemplate = {
  MONDAY: workInterval,
  TUESDAY: workInterval,
  WEDNESDAY: workInterval,
  THURSDAY: workInterval,
  FRIDAY: workInterval,
  SATURDAY: workInterval,
  SUNDAY: workInterval,
}

async function configureAvailability(request: APIRequestContext) {
  const currentResponse = await request.get('/api/owner/availability')
  expect(currentResponse.status()).toBe(200)
  const current = await currentResponse.json()
  const response = await request.put('/api/owner/availability', {
    data: {
      timeZone: 'UTC',
      expectedVersion: current.exists ? current.version : null,
      weeklyTemplate,
      exceptions: [],
    },
  })
  expect(response.status()).toBe(200)
}

test('гость бронирует встречу, а владелец видит её в деталях', async ({ page, request }) => {
  await configureAvailability(request)
  const meetingTypeName = `E2E консультация ${Date.now()}`
  const guestName = 'E2E Гость'

  await page.goto('/owner/meeting-types')
  await page.getByLabel('Название', { exact: true }).fill(meetingTypeName)
  await page.getByLabel('Описание', { exact: true }).fill('Проверка браузерного сценария')
  await page.getByLabel('Длительность (минуты)', { exact: true }).fill('30')
  await page.getByRole('button', { name: 'Создать тип', exact: true }).click()
  await expect(page.getByRole('status').filter({ hasText: 'Тип встречи создан' })).toBeVisible()

  await page.goto('/book')
  await page.getByRole('button').filter({ hasText: meetingTypeName }).click()
  await page.locator('.booking-dates button:enabled').first().click()
  await page.locator('.booking-slots button:enabled').first().click()
  await page.getByLabel('Имя', { exact: true }).fill(guestName)
  await page.getByLabel('Email', { exact: true }).fill('e2e@example.com')
  await page.getByRole('button', { name: 'Забронировать', exact: true }).click()

  await expect(page.getByRole('heading', { name: 'Встреча забронирована' })).toBeVisible()
  await page.screenshot({ path: test.info().outputPath('confirmation.png'), fullPage: true })

  await page.goto('/owner')
  const meeting = page
    .locator('article')
    .filter({ hasText: guestName })
    .filter({ hasText: meetingTypeName })
  await expect(meeting).toContainText(meetingTypeName)
  await expect(meeting).toContainText('e2e@example.com')
})

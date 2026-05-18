package com.invoiceflow.features.dashboard.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

/**
 * Matches AutoMyInvoiceWeb.Api.DashboardController.index/2 — only the four
 * KPIs the web app surfaces on its dashboard. We keep this payload tiny;
 * analytics charts come from /dashboard/analytics, which the mobile app
 * does not need on the home screen.
 *
 * `outstandingAmount` is always in KRW — AMI-90 rolls non-KRW invoices
 * into KRW via amount_krw before summing on the server side. Both money
 * fields are strings because Phoenix renders Decimal as a string to
 * preserve precision; the UI converts to BigDecimal when needed.
 */
@JsonClass(generateAdapter = true)
data class KpiSummaryDto(
    @Json(name = "outstanding_amount") val outstandingAmount: String,
    @Json(name = "overdue_count") val overdueCount: Int,
    @Json(name = "collection_rate") val collectionRate: Int,
    @Json(name = "collected_this_month") val collectedThisMonth: String,
)

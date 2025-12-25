# Up Bank API - Comprehensive Overview & Guide

**Document Version:** 2.0  
**Last Updated:** December 2025  
**Source:** [Up Bank API Documentation](https://developer.up.com.au/#welcome)

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [API Fundamentals](#api-fundamentals)
3. [Accounts](#accounts)
4. [Transactions](#transactions)
5. [Categories](#categories)
6. [Tags](#tags)
7. [Attachments](#attachments)
8. [Webhooks](#webhooks)
9. [Utility Endpoints](#utility-endpoints)
10. [Rate Limits](#rate-limits)
11. [Use Cases for Desktop/PWA Application](#use-cases)

---

## Getting Started

### Personal Access Token (PAT)

To interact with the Up API, you need a Personal Access Token (PAT), which serves as your authentication credential.

**How to Obtain:**
1. Open the Up mobile app on your device
2. Navigate to "Data Sharing" in settings
3. Select "Personal Access Token" to generate your token

**Security Note:** Treat your PAT like a password. Keep it secure and never share it publicly. If you suspect it has been compromised, regenerate it immediately through the Up app.

---

## API Fundamentals

### Base URL Structure

All API requests use this base URL:

```
https://api.up.com.au/api/v1/
```

**Examples:**
- List accounts: `https://api.up.com.au/api/v1/accounts`
- Get transaction: `https://api.up.com.au/api/v1/transactions/{id}`

### Authentication

Include your Personal Access Token in the `Authorization` header:

```http
Authorization: Bearer YOUR_PERSONAL_ACCESS_TOKEN
```

**Example Request:**
```bash
curl -X GET https://api.up.com.au/api/v1/accounts \
  -H "Authorization: Bearer up:yeah:YOUR_TOKEN_HERE"
```

### Pagination

The API uses cursor-based pagination. Responses include `links` for navigating between pages.

**Parameters:**
- `page[size]`: Number of results per page (default varies by endpoint)
- `page[after]`: Cursor token for the next page (from the `links.next` field)

**Example Request:**
```http
GET /transactions?page[size]=20&page[after]=WyIyMDI1LTEyLTA0VDAwOjM0OjUxLjg0NzI4ODAwMFoiLCIxOTU4M2Q1NS00ZGI0LTRhNDMtOTg3NC00MzU1YzI1MGE3ZmIiXQ%3D%3D
```

**Response Structure:**
```json
{
  "data": [...],
  "links": {
    "prev": null,
    "next": "https://api.up.com.au/api/v1/transactions?page[after]=...&page[size]=20"
  }
}
```

**Real-World Example:**
To fetch all transactions, start with the first page, then use `links.next` to fetch subsequent pages until `next` is `null`.

### Error Responses

The API returns standard HTTP status codes and JSON error responses.

**Common Status Codes:**
- `200` - Success
- `400` - Bad Request (invalid parameters)
- `401` - Unauthorized (invalid or missing token)
- `404` - Not Found (resource doesn't exist)
- `429` - Too Many Requests (rate limit exceeded)
- `500` - Internal Server Error

**Error Response Format:**
```json
{
  "errors": [
    {
      "status": "400",
      "title": "Bad Request",
      "detail": "Invalid parameter provided"
    }
  ]
}
```

---

## Accounts

Accounts represent your bank accounts within Up, including transaction accounts, savings accounts, and home loan accounts.

### List Accounts

**Endpoint:** `GET /accounts`

**Description:** Returns all accounts associated with your Up account.

**Example Response:**
```json
{
  "data": [
    {
      "type": "accounts",
      "id": "1234-5678-9012-3456",
      "attributes": {
        "displayName": "Everyday Account",
        "accountType": "TRANSACTIONAL",
        "ownershipType": "INDIVIDUAL",
        "balance": {
          "currencyCode": "AUD",
          "value": "1500.00",
          "valueInBaseUnits": 150000
        },
        "createdAt": "2025-01-01T00:00:00+11:00"
      },
      "relationships": {
        "transactions": {
          "links": {
            "related": "https://api.up.com.au/api/v1/accounts/1234-5678-9012-3456/transactions"
          }
        }
      },
      "links": {
        "self": "https://api.up.com.au/api/v1/accounts/1234-5678-9012-3456"
      }
    },
    {
      "type": "accounts",
      "id": "9876-5432-1098-7654",
      "attributes": {
        "displayName": "Savings Account",
        "accountType": "SAVER",
        "ownershipType": "JOINT",
        "balance": {
          "currencyCode": "AUD",
          "value": "5000.00",
          "valueInBaseUnits": 500000
        },
        "createdAt": "2025-01-15T00:00:00+11:00"
      },
      "relationships": {
        "transactions": {
          "links": {
            "related": "https://api.up.com.au/api/v1/accounts/9876-5432-1098-7654/transactions"
          }
        }
      },
      "links": {
        "self": "https://api.up.com.au/api/v1/accounts/9876-5432-1098-7654"
      }
    }
  ],
  "links": {
    "prev": null,
    "next": null
  }
}
```

**Field Explanations:**
- **`displayName`**: The name you've assigned to the account (e.g., "Everyday Account", "Savings Account")
- **`accountType`**: Type of account - **ONLY THREE TYPES EXIST**:
  - `TRANSACTIONAL` - Everyday spending accounts
  - `SAVER` - Savings accounts
  - `HOME_LOAN` - Home loan accounts
- **`ownershipType`**: Ownership structure:
  - `INDIVIDUAL` - Single ownership
  - `JOINT` - Shared ownership
- **`balance.value`**: Human-readable balance (e.g., "1500.00")
- **`balance.valueInBaseUnits`**: Balance in cents (e.g., 150000 = $1,500.00)
- **`balance.currencyCode`**: Currency code (typically "AUD" for Australian Dollars)
- **`createdAt`**: Date and time when the account was created
- **`relationships.transactions`**: Link to fetch transactions for this specific account

**Real-World Use Case:**
Display a dashboard showing all accounts with their current balances. Use the `relationships.transactions.links.related` to fetch transactions for a specific account when needed.

### Retrieve Account

**Endpoint:** `GET /accounts/{id}`

**Description:** Returns details for a specific account.

**Example Request:**
```bash
curl -X GET https://api.up.com.au/api/v1/accounts/1234-5678-9012-3456 \
  -H "Authorization: Bearer YOUR_PERSONAL_ACCESS_TOKEN"
```

**Response:** Same structure as a single account object from the list endpoint.

**Real-World Use Case:**
Show detailed account information when a user selects a specific account.

---

## Transactions

Transactions represent individual movements of money in or out of your accounts.

### List Transactions

**Endpoint:** `GET /transactions`

**Description:** Returns all transactions across all accounts.

**Query Parameters:**
- `page[size]`: Number of results per page
- `page[after]`: Cursor for pagination
- `filter[status]`: Filter by status (`HELD` or `SETTLED`) - **ONLY TWO STATUSES EXIST**
- `filter[since]`: Filter transactions from a specific date-time (RFC 3339 format)
- `filter[until]`: Filter transactions up to a specific date-time (RFC 3339 format)

**Note:** These are the **ONLY** filter parameters available for transactions.

**Example Response:**
```json
{
  "data": [
    {
      "type": "transactions",
      "id": "abcd-efgh-ijkl-mnop",
      "attributes": {
        "status": "SETTLED",
        "rawText": "COFFEE SHOP MELBOURNE",
        "description": "Coffee Shop",
        "message": "Morning coffee",
        "isCategorizable": true,
        "holdInfo": null,
        "roundUp": null,
        "cashback": null,
        "amount": {
          "currencyCode": "AUD",
          "value": "-4.50",
          "valueInBaseUnits": -450
        },
        "foreignAmount": null,
        "cardPurchaseMethod": null,
        "settledAt": "2025-12-23T09:00:00+11:00",
        "createdAt": "2025-12-23T08:30:00+11:00"
      },
      "relationships": {
        "account": {
          "data": {
            "type": "accounts",
            "id": "1234-5678-9012-3456"
          },
          "links": {
            "related": "https://api.up.com.au/api/v1/accounts/1234-5678-9012-3456"
          }
        },
        "category": {
          "data": {
            "type": "categories",
            "id": "restaurants-and-cafes"
          },
          "links": {
            "related": "https://api.up.com.au/api/v1/categories/restaurants-and-cafes"
          }
        },
        "parentCategory": {
          "data": {
            "type": "categories",
            "id": "good-life"
          },
          "links": {
            "related": "https://api.up.com.au/api/v1/categories/good-life"
          }
        },
        "tags": {
          "data": [
            {
              "type": "tags",
              "id": "morning"
            }
          ]
        },
        "attachment": {
          "data": null
        }
      },
      "links": {
        "self": "https://api.up.com.au/api/v1/transactions/abcd-efgh-ijkl-mnop"
      }
    },
    {
      "type": "transactions",
      "id": "wxyz-1234-5678-9012",
      "attributes": {
        "status": "HELD",
        "rawText": "HOTEL DEPOSIT",
        "description": "Hotel Booking",
        "message": null,
        "isCategorizable": true,
        "amount": {
          "currencyCode": "AUD",
          "value": "-200.00",
          "valueInBaseUnits": -20000
        },
        "createdAt": "2025-12-24T10:00:00+11:00",
        "settledAt": null,
        "holdInfo": {
          "amount": {
            "currencyCode": "AUD",
            "value": "-200.00",
            "valueInBaseUnits": -20000
          },
          "foreignAmount": null
        }
      },
      "relationships": {
        "account": {
          "data": {
            "type": "accounts",
            "id": "1234-5678-9012-3456"
          }
        },
        "category": {
          "data": null
        },
        "tags": {
          "data": []
        }
      },
      "links": {
        "self": "https://api.up.com.au/api/v1/transactions/wxyz-1234-5678-9012"
      }
    }
  ],
  "links": {
    "prev": null,
    "next": "https://api.up.com.au/api/v1/transactions?page[after]=..."
  }
}
```

**Field Explanations:**
- **`status`**: Transaction status - **ONLY TWO STATUSES EXIST**:
  - `HELD` - Pending transactions (not yet settled)
  - `SETTLED` - Completed transactions
- **`rawText`**: Raw transaction text from the bank
- **`description`**: Processed merchant/transaction description
- **`message`**: Optional message associated with the transaction (can be null)
- **`amount.value`**: Human-readable amount (negative for debits, positive for credits)
- **`amount.valueInBaseUnits`**: Amount in cents (negative for debits, positive for credits)
- **`createdAt`**: Date and time when the transaction was created
- **`settledAt`**: Date and time when the transaction settled (null for HELD transactions)
- **`holdInfo`**: Present for HELD transactions, contains hold amount information
- **`relationships.account`**: Associated account
- **`relationships.category`**: Category assigned to the transaction (may be null)
- **`relationships.parentCategory`**: Parent category if category has a parent
- **`relationships.tags`**: Array of tags associated with the transaction
- **`relationships.attachment`**: Associated attachment (receipt/document) if present

**Real-World Use Cases:**
- Display transaction history with filtering by status
- Show pending vs settled transactions separately
- Analyze spending patterns by category
- Track expenses for budgeting
- Filter transactions by date range for reports

### Retrieve Transaction

**Endpoint:** `GET /transactions/{id}`

**Description:** Returns details for a specific transaction.

**Example Request:**
```bash
curl -X GET https://api.up.com.au/api/v1/transactions/abcd-efgh-ijkl-mnop \
  -H "Authorization: Bearer YOUR_PERSONAL_ACCESS_TOKEN"
```

**Response:** Same structure as a single transaction object from the list endpoint.

**Real-World Use Case:**
Show detailed transaction information when a user clicks on a specific transaction.

### List Transactions by Account

**Endpoint:** `GET /accounts/{accountId}/transactions`

**Description:** Returns transactions for a specific account.

**Example Request:**
```bash
curl -X GET https://api.up.com.au/api/v1/accounts/1234-5678-9012-3456/transactions \
  -H "Authorization: Bearer YOUR_PERSONAL_ACCESS_TOKEN"
```

**Response:** Same structure as the transactions list, filtered to the specified account.

**Real-World Use Case:**
Show transactions for a specific account when a user views account details.

---

## Categories

Categories help organize transactions into meaningful groups for spending analysis. The category system is hierarchical, with parent categories containing child categories.

### Category Structure

Categories have a hierarchical parent-child relationship:
- Each category has a unique `id` (e.g., "eating_out", "restaurants")
- Categories have a human-readable `name` (e.g., "Eating Out", "Restaurants")
- Top-level categories have `parent: null`
- Child categories reference their parent in the `relationships.parent` field

**Important:** The complete list of categories is dynamic and must be fetched from the API. Categories may be updated by Up over time, so always fetch the current list rather than hardcoding category IDs.

### List Categories

**Endpoint:** `GET /categories`

**Description:** Retrieves all available categories and their hierarchy.

**Example Request:**
```bash
curl -X GET https://api.up.com.au/api/v1/categories \
  -H "Authorization: Bearer YOUR_PERSONAL_ACCESS_TOKEN"
```

**Example Response Structure:**
```json
{
  "data": [
    {
      "type": "categories",
      "id": "good-life",
      "attributes": {
        "name": "Good Life"
      },
      "relationships": {
        "parent": {
          "data": null
        },
        "children": {
          "data": [
            {
              "type": "categories",
              "id": "games-and-software"
            },
            {
              "type": "categories",
              "id": "restaurants-and-cafes"
            }
          ]
        }
      },
      "links": {
        "self": "https://api.up.com.au/api/v1/categories/good-life"
      }
    }
  ]
}
```

### Complete Category Hierarchy

Based on the API response, here is the complete category structure:

#### Top-Level Categories (Parent: null)

**1. Good Life** (`good-life`)
   - Apps, Games & Software (`games-and-software`)
   - Booze (`booze`)
   - Events & Gigs (`events-and-gigs`)
   - Hobbies (`hobbies`)
   - Holidays & Travel (`holidays-and-travel`)
   - Lottery & Gambling (`lottery-and-gambling`)
   - Pubs & Bars (`pubs-and-bars`)
   - Restaurants & Cafes (`restaurants-and-cafes`)
   - Takeaway (`takeaway`)
   - Tobacco & Vaping (`tobacco-and-vaping`)
   - TV, Music & Streaming (`tv-and-music`)
   - Adult (`adult`)

**2. Home** (`home`)
   - Groceries (`groceries`)
   - Homeware & Appliances (`homeware-and-appliances`)
   - Internet (`internet`)
   - Maintenance & Improvements (`home-maintenance-and-improvements`)
   - Pets (`pets`)
   - Rates & Insurance (`home-insurance-and-rates`)
   - Rent & Mortgage (`rent-and-mortgage`)
   - Utilities (`utilities`)

**3. Personal** (`personal`)
   - Children & Family (`family`)
   - Clothing & Accessories (`clothing-and-accessories`)
   - Education & Student Loans (`education-and-student-loans`)
   - Fitness & Wellbeing (`fitness-and-wellbeing`)
   - Gifts & Charity (`gifts-and-charity`)
   - Hair & Beauty (`hair-and-beauty`)
   - Health & Medical (`health-and-medical`)
   - Investments (`investments`)
   - Life Admin (`life-admin`)
   - Mobile Phone (`mobile-phone`)
   - News, Magazines & Books (`news-magazines-and-books`)
   - Technology (`technology`)

**4. Transport** (`transport`)
   - Car Insurance, Rego & Maintenance (`car-insurance-and-maintenance`)
   - Cycling (`cycling`)
   - Fuel (`fuel`)
   - Parking (`parking`)
   - Public Transport (`public-transport`)
   - Repayments (`car-repayments`)
   - Taxis & Share Cars (`taxis-and-share-cars`)
   - Tolls (`toll-roads`)

**Total Categories:** 4 top-level categories with 43 child categories = **47 total categories**

### Retrieve Category

**Endpoint:** `GET /categories/{id}`

**Description:** Returns details for a specific category.

**Example Request:**
```bash
curl -X GET https://api.up.com.au/api/v1/categories/good-life \
  -H "Authorization: Bearer YOUR_PERSONAL_ACCESS_TOKEN"
```

**Response:** Same structure as a single category object from the list endpoint.

**Real-World Use Case:**
Show category details when building budget interfaces or category selection dropdowns.

### Categorize Transaction

**Endpoint:** `PUT /transactions/{transactionId}/relationships/category`

**Description:** Assigns or updates a transaction's category.

**Request Body:**
```json
{
  "data": {
    "type": "categories",
    "id": "restaurants-and-cafes"
  }
}
```

**Example Request:**
```bash
curl -X PUT https://api.up.com.au/api/v1/transactions/abcd-efgh-ijkl-mnop/relationships/category \
  -H "Authorization: Bearer YOUR_PERSONAL_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "type": "categories",
      "id": "restaurants-and-cafes"
    }
  }'
```

**Response:** Returns the updated transaction with the new category.

**Real-World Use Case:**
Allow users to recategorize transactions manually for better budgeting accuracy.

---

## Tags

Tags are custom labels that you can assign to transactions for flexible organization beyond categories.

### List Tags

**Endpoint:** `GET /tags`

**Description:** Returns all tags you've created.

**Example Response:**
```json
{
  "data": [
    {
      "type": "tags",
      "id": "holiday"
    },
    {
      "type": "tags",
      "id": "groceries"
    },
    {
      "type": "tags",
      "id": "morning"
    }
  ],
  "links": {
    "prev": null,
    "next": null
  }
}
```

**Field Explanations:**
- **`id`**: The tag identifier (the tag name itself - case-sensitive)

**Real-World Use Case:**
Show all available tags for filtering or assignment in your application.

### Add Tags to Transaction

**Endpoint:** `POST /transactions/{transactionId}/relationships/tags`

**Description:** Adds one or more tags to a transaction.

**Request Body:**
```json
{
  "data": [
    {
      "type": "tags",
      "id": "holiday"
    },
    {
      "type": "tags",
      "id": "queensland"
    }
  ]
}
```

**Example Request:**
```bash
curl -X POST https://api.up.com.au/api/v1/transactions/abcd-efgh-ijkl-mnop/relationships/tags \
  -H "Authorization: Bearer YOUR_PERSONAL_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": [
      {
        "type": "tags",
        "id": "holiday"
      },
      {
        "type": "tags",
        "id": "queensland"
      }
    ]
  }'
```

**Response:** Returns the updated transaction with the new tags.

**Real-World Use Case:**
Tag vacation expenses with "holiday" and location tags for later analysis, or tag business expenses with "business" for tax purposes.

### Remove Tags from Transaction

**Endpoint:** `DELETE /transactions/{transactionId}/relationships/tags`

**Description:** Removes one or more tags from a transaction.

**Request Body:**
```json
{
  "data": [
    {
      "type": "tags",
      "id": "holiday"
    }
  ]
}
```

**Example Request:**
```bash
curl -X DELETE https://api.up.com.au/api/v1/transactions/abcd-efgh-ijkl-mnop/relationships/tags \
  -H "Authorization: Bearer YOUR_PERSONAL_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": [
      {
        "type": "tags",
        "id": "holiday"
      }
    ]
  }'
```

**Response:** Returns the updated transaction without the removed tags.

**Real-World Use Case:**
Remove incorrect tags or clean up tag assignments.

---

## Attachments

Attachments are files (such as receipts) associated with transactions. **Note: Attachments are read-only via the API - they can only be created through the Up mobile app.**

### List Attachments

**Endpoint:** `GET /attachments`

**Description:** Returns all attachments across your transactions.

**Example Response:**
```json
{
  "data": [
    {
      "type": "attachments",
      "id": "attachment-id-123",
      "attributes": {
        "fileType": "image/jpeg",
        "fileSize": 245678,
        "fileName": "receipt.jpg",
        "url": "https://api.up.com.au/api/v1/attachments/attachment-id-123/file",
        "urlExpiresAt": "2025-12-23T11:48:36+11:00",
        "createdAt": "2025-12-23T08:35:00+11:00"
      },
      "relationships": {
        "transaction": {
          "data": {
            "type": "transactions",
            "id": "abcd-efgh-ijkl-mnop"
          },
          "links": {
            "related": "https://api.up.com.au/api/v1/transactions/abcd-efgh-ijkl-mnop"
          }
        }
      },
      "links": {
        "self": "https://api.up.com.au/api/v1/attachments/attachment-id-123"
      }
    }
  ],
  "links": {
    "prev": null,
    "next": null
  }
}
```

**Field Explanations:**
- **`fileType`**: MIME type (e.g., "image/jpeg", "image/png", "application/pdf")
- **`fileSize`**: Size in bytes
- **`fileName`**: Original filename
- **`url`**: URL to download the file (temporary, expires)
- **`urlExpiresAt`**: Expiration time for the download URL
- **`createdAt`**: Date and time when the attachment was created
- **`relationships.transaction`**: Associated transaction

**Important Limitations:**
- **No Upload Capability**: Attachments cannot be created or uploaded via the API
- Attachments must be created through the Up mobile app
- Download URLs are temporary and expire

**Real-World Use Cases:**
- Display receipt images associated with transactions
- Download receipts for expense reports
- Organize receipts by transaction

### Retrieve Attachment

**Endpoint:** `GET /attachments/{id}`

**Description:** Returns details for a specific attachment.

**Example Request:**
```bash
curl -X GET https://api.up.com.au/api/v1/attachments/attachment-id-123 \
  -H "Authorization: Bearer YOUR_PERSONAL_ACCESS_TOKEN"
```

**Response:** Same structure as a single attachment object from the list endpoint.

**Downloading the File:**
Use the `attributes.url` field to download the actual file:

```bash
curl -X GET https://api.up.com.au/api/v1/attachments/attachment-id-123/file \
  -H "Authorization: Bearer YOUR_PERSONAL_ACCESS_TOKEN" \
  --output receipt.jpg
```

**Real-World Use Case:**
Show attachment details and allow users to download receipts.

---

## Webhooks

Webhooks allow your application to receive real-time notifications about events in your Up account.

### List Webhooks

**Endpoint:** `GET /webhooks`

**Description:** Returns all configured webhooks.

**Example Response:**
```json
{
  "data": [
    {
      "type": "webhooks",
      "id": "webhook-id-123",
      "attributes": {
        "url": "https://yourapp.com/webhooks/up",
        "description": "Transaction notifications",
        "secretKey": "whsec_abc123...",
        "createdAt": "2025-12-01T00:00:00+11:00"
      },
      "relationships": {
        "logs": {
          "links": {
            "related": "https://api.up.com.au/api/v1/webhooks/webhook-id-123/logs"
          }
        }
      },
      "links": {
        "self": "https://api.up.com.au/api/v1/webhooks/webhook-id-123"
      }
    }
  ],
  "links": {
    "prev": null,
    "next": null
  }
}
```

**Field Explanations:**
- **`url`**: Your webhook endpoint URL
- **`description`**: Optional description for the webhook
- **`secretKey`**: Secret key for signature verification (store securely - only shown once at creation)
- **`createdAt`**: Date and time when the webhook was created
- **`relationships.logs`**: Link to webhook delivery logs

**Real-World Use Case:**
Manage webhooks in your application settings.

### Create Webhook

**Endpoint:** `POST /webhooks`

**Description:** Creates a new webhook.

**Request Body:**
```json
{
  "data": {
    "attributes": {
      "url": "https://yourapp.com/webhooks/up",
      "description": "Transaction notifications for my app"
    }
  }
}
```

**Example Request:**
```bash
curl -X POST https://api.up.com.au/api/v1/webhooks \
  -H "Authorization: Bearer YOUR_PERSONAL_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "attributes": {
        "url": "https://yourapp.com/webhooks/up",
        "description": "Transaction notifications"
      }
    }
  }'
```

**Response:** Returns the created webhook with a `secretKey` - **save this securely as it's only shown once**.

**Real-World Use Case:**
Set up real-time transaction notifications when users connect their account.

### Retrieve Webhook

**Endpoint:** `GET /webhooks/{id}`

**Description:** Returns details for a specific webhook.

**Example Request:**
```bash
curl -X GET https://api.up.com.au/api/v1/webhooks/webhook-id-123 \
  -H "Authorization: Bearer YOUR_PERSONAL_ACCESS_TOKEN"
```

**Response:** Same structure as a single webhook object from the list endpoint (note: `secretKey` is not returned after creation).

### Delete Webhook

**Endpoint:** `DELETE /webhooks/{id}`

**Description:** Deletes a webhook.

**Example Request:**
```bash
curl -X DELETE https://api.up.com.au/api/v1/webhooks/webhook-id-123 \
  -H "Authorization: Bearer YOUR_PERSONAL_ACCESS_TOKEN"
```

**Response:** `204 No Content` on success.

**Real-World Use Case:**
Remove webhooks when users disconnect their account.

### Ping Webhook

**Endpoint:** `POST /webhooks/{id}/ping`

**Description:** Sends a test `PING` event to your webhook URL.

**Example Request:**
```bash
curl -X POST https://api.up.com.au/api/v1/webhooks/webhook-id-123/ping \
  -H "Authorization: Bearer YOUR_PERSONAL_ACCESS_TOKEN"
```

**Response:** `204 No Content` on success. A `PING` event will be sent to your webhook URL.

**Real-World Use Case:**
Test webhook configuration and delivery.

### List Webhook Logs

**Endpoint:** `GET /webhooks/{id}/logs`

**Description:** Returns delivery logs for a webhook.

**Example Response:**
```json
{
  "data": [
    {
      "type": "webhook-delivery-logs",
      "id": "log-id-123",
      "attributes": {
        "request": {
          "body": "{\"data\":{...}}",
          "headers": {
            "Content-Type": "application/json",
            "X-Up-Authenticity-Signature": "317c0a8ea81df3f53c1d2aef5dcbf60492d0df557197b2990e71daa4a0693364"
          },
          "url": "https://yourapp.com/webhooks/up"
        },
        "response": {
          "statusCode": 200,
          "body": "{\"ok\":true}"
        },
        "deliveryStatus": "DELIVERED",
        "createdAt": "2025-12-04T11:34:51+11:00"
      },
      "relationships": {
        "webhookEvent": {
          "data": {
            "type": "webhook-events",
            "id": "04007723-0a8e-4563-8255-d0682b8e3f04"
          }
        }
      }
    }
  ],
  "links": {
    "prev": null,
    "next": "https://api.up.com.au/api/v1/webhooks/webhook-id-123/logs?page[after]=..."
  }
}
```

**Field Explanations:**
- **`request`**: The request sent to your webhook
- **`response`**: Your webhook's response
- **`deliveryStatus`**: Status of delivery (`DELIVERED`, `PENDING`, or `FAILED`)
- **`createdAt`**: Date and time when the delivery attempt occurred

**Real-World Use Case:**
Debug webhook delivery issues.

### Handling Webhook Events

When events occur, Up sends `POST` requests to your webhook URL.

**Important Requirements:**
- Your endpoint must respond with HTTP `200` on success
- **Must respond within 30 seconds** (requests timeout after 30 seconds)
- Avoid heavy processing before responding (use async queues if needed)
- Retries use exponential backoff for non-200 responses

**Request Headers:**
```http
X-Up-Authenticity-Signature: 317c0a8ea81df3f53c1d2aef5dcbf60492d0df557197b2990e71daa4a0693364
Content-Type: application/json
```

**Request Payload Example:**
```json
{
  "data": {
    "type": "webhook-events",
    "id": "494a6393-d39f-46bc-b9fa-1fa5264f1a18",
    "attributes": {
      "eventType": "TRANSACTION_CREATED",
      "createdAt": "2025-12-05T11:33:50+11:00"
    },
    "relationships": {
      "webhook": {
        "data": {
          "type": "webhooks",
          "id": "92d94b71-5d52-4170-89f9-36ef6e38b9dc"
        },
        "links": {
          "related": "https://api.up.com.au/api/v1/webhooks/92d94b71-5d52-4170-89f9-36ef6e38b9dc"
        }
      },
      "transaction": {
        "data": {
          "type": "transactions",
          "id": "66d6d95a-87fa-4af5-86d0-66d0fe6f530f"
        },
        "links": {
          "related": "https://api.up.com.au/api/v1/transactions/66d6d95a-87fa-4af5-86d0-66d0fe6f530f"
        }
      }
    }
  }
}
```

**Event Types:**

1. **`PING`**
   - Manually triggered via the ping endpoint
   - Used for testing and debugging

2. **`TRANSACTION_CREATED`**
   - Triggered when a new transaction is created
   - Includes a `transaction` relationship with a link to fetch full details

3. **`TRANSACTION_SETTLED`**
   - Triggered when a transaction transitions from `HELD` to `SETTLED`
   - Includes a `transaction` relationship
   - **Note:** On rare occasions, this event may not be triggered due to external banking factors. In such cases, `TRANSACTION_DELETED` and `TRANSACTION_CREATED` events will be received instead.

4. **`TRANSACTION_DELETED`**
   - Triggered when a `HELD` transaction is deleted (e.g., hotel deposit returned)
   - Includes a `transaction` relationship, but **no link** (transaction no longer exists)

### Webhook Security - Signature Verification

Verify the `X-Up-Authenticity-Signature` header using the webhook's `secretKey`:

1. Take the raw, unparsed request body
2. Compute SHA-256 HMAC of the body using the `secretKey`
3. Compare with the `X-Up-Authenticity-Signature` header value

**Example (Node.js):**
```javascript
const crypto = require('crypto');

function verifyWebhookSignature(rawBody, signature, secretKey) {
  const computedSignature = crypto
    .createHmac('sha256', secretKey)
    .update(rawBody)
    .digest('hex');
  
  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(computedSignature)
  );
}
```

**Example (Python):**
```python
import hmac
import hashlib

def verify_webhook_signature(raw_body, signature, secret_key):
    computed_signature = hmac.new(
        secret_key.encode('utf-8'),
        raw_body.encode('utf-8'),
        hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(computed_signature, signature)
```

**Real-World Use Cases:**
- Real-time transaction notifications
- Automatic budget alerts
- Instant balance updates
- Transaction categorization automation

---

## Utility Endpoints

### Ping

**Endpoint:** `GET /util/ping`

**Description:** Health check endpoint to verify API connectivity and authentication.

**Example Request:**
```bash
curl -X GET https://api.up.com.au/api/v1/util/ping \
  -H "Authorization: Bearer YOUR_PERSONAL_ACCESS_TOKEN"
```

**Example Response:**
```json
{
  "meta": {
    "statusEmoji": "✅"
  }
}
```

**Real-World Use Case:**
Verify API connectivity and token validity on app startup.

---

## Rate Limits

The Up API implements rate limiting to ensure fair usage. When you exceed the rate limit:

**Rate Limit Response:**
- HTTP Status: `429 Too Many Requests`
- Response Header: `X-RateLimit-Remaining` shows the number of requests remaining in the current window

**Best Practices:**
- Monitor the `X-RateLimit-Remaining` header in responses
- Implement exponential backoff when receiving `429` responses
- Avoid making unnecessary or redundant API calls
- Cache responses when appropriate

**Example Response Headers:**
```http
HTTP/1.1 200 OK
X-RateLimit-Remaining: 45
Content-Type: application/json
```

**Handling Rate Limits:**
```javascript
async function makeRequestWithRetry(url, token, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    const response = await fetch(url, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    
    if (response.status === 429) {
      const waitTime = Math.pow(2, i) * 1000; // Exponential backoff
      await new Promise(resolve => setTimeout(resolve, waitTime));
      continue;
    }
    
    const remaining = response.headers.get('X-RateLimit-Remaining');
    console.log(`Requests remaining: ${remaining}`);
    
    return response;
  }
  throw new Error('Max retries exceeded');
}
```

**Example (Python):**
```python
import time
import requests

def make_request_with_retry(url, token, max_retries=3):
    for i in range(max_retries):
        response = requests.get(
            url,
            headers={'Authorization': f'Bearer {token}'}
        )
        
        if response.status_code == 429:
            wait_time = (2 ** i)  # Exponential backoff in seconds
            time.sleep(wait_time)
            continue
        
        remaining = response.headers.get('X-RateLimit-Remaining')
        print(f'Requests remaining: {remaining}')
        
        return response
    
    raise Exception('Max retries exceeded')
```

**Note:** The specific rate limit values (requests per minute/hour) are not publicly documented. Monitor the `X-RateLimit-Remaining` header to understand your current usage patterns.

---

## Use Cases for Desktop/PWA Application

### Data Flow Diagram

```mermaid
graph TD
    A[User Opens App] --> B[Authenticate with PAT]
    B --> C{Fetch Accounts}
    C --> D[Display Account Balances]
    C --> E[Fetch Transactions]
    E --> F[Display Transaction History]
    F --> G[Analyze by Category]
    G --> H[Budget Tracking]
    E --> I[Filter by Tags]
    I --> J[Custom Reports]
    K[Webhook Event] --> L[Real-time Update]
    L --> M[Notify User]
    L --> N[Update Budget Status]
```

### Budgeting Features

**What You Can Build:**
1. **Spending Analysis**
   - Fetch transactions → Group by category → Calculate totals
   - Compare spending across time periods (weekly, monthly, yearly)
   - Identify top spending categories
   - Show spending trends over time

2. **Budget Limits**
   - Let users set monthly/weekly limits per category
   - Monitor spending against limits
   - Use webhooks to alert when approaching/exceeding limits
   - Visual progress indicators

3. **Visualizations**
   - Pie charts by category
   - Line charts showing trends over time
   - Bar charts comparing budget vs actual
   - Spending heatmaps by day/week

**Implementation Flow:**
```mermaid
graph LR
    A[Fetch Transactions] --> B[Group by Category]
    B --> C[Calculate Totals]
    C --> D[Compare to Budget]
    D --> E{Over Budget?}
    E -->|Yes| F[Alert User]
    E -->|No| G[Show Progress]
```

**Example Category-Based Budget:**
- Set monthly limit for "Restaurants & Cafes" category: $500
- Monitor transactions in `restaurants-and-cafes` category
- Alert when spending reaches 80% of limit
- Show remaining budget and spending rate

### Investing Features

**What You Can Build:**
1. **Savings Tracking**
   - Monitor savings account balances over time
   - Track deposits to savings accounts
   - Calculate growth rate and projections
   - Set savings goals

2. **Investment Transaction Tracking**
   - Tag investment-related transactions (e.g., "investment", "dividend")
   - Track deposits to investment platforms
   - Monitor returns/dividends as credits
   - Calculate investment activity frequency

3. **Portfolio Integration**
   - Link with external investment APIs (if available)
   - Correlate bank transactions with investment activity
   - Track net worth (bank balances + investments)
   - Show cash flow to/from investments

**Note:** The Up API does not provide direct investment account access. You can:
- Track money movements related to investing
- Monitor savings growth
- Integrate with external investment platforms using transaction data
- Use the "Investments" category (`investments`) to track investment-related expenses

**Implementation Flow:**
```mermaid
graph TD
    A[Fetch Accounts] --> B[Identify Savings Accounts]
    B --> C[Track Balance Changes]
    C --> D[Calculate Growth Rate]
    E[Tag Investment Transactions] --> F[Track Investment Activity]
    F --> G[Integrate External APIs]
    G --> H[Calculate Net Worth]
```

### Complete Application Architecture

```mermaid
graph TB
    subgraph "Frontend - Desktop/PWA"
        A[Account Dashboard]
        B[Transaction List]
        C[Budget Manager]
        D[Investment Tracker]
        E[Settings]
    end
    
    subgraph "Backend/API Layer"
        F[Up API Client]
        G[Webhook Handler]
        H[Budget Engine]
        I[Analytics Engine]
    end
    
    subgraph "Data Storage"
        J[User Preferences]
        K[Budget Limits]
        L[Investment Links]
    end
    
    subgraph "External Services"
        M[Up Bank API]
        N[Investment APIs]
    end
    
    A --> F
    B --> F
    C --> H
    D --> I
    E --> J
    F --> M
    G --> M
    H --> K
    I --> L
    I --> N
    G --> H
    G --> I
```

---

## Summary

### What the Up API Provides

✅ **Accounts**: List and retrieve account details with balances and ownership types  
✅ **Transactions**: Full transaction history with filtering and pagination (status: HELD/SETTLED only)  
✅ **Categories**: Hierarchical category system with 47 total categories (4 parent, 43 children)  
✅ **Tags**: Custom labels for flexible transaction organization  
✅ **Attachments**: Receipt and document retrieval (read-only, no upload)  
✅ **Webhooks**: Real-time event notifications with 30-second timeout requirement  
✅ **Utility**: Health check endpoint  

### What You Can Build

1. **Desktop/PWA Banking App**
   - Full account dashboard with real-time balances
   - Comprehensive transaction history with filtering
   - Receipt management and viewing
   - Real-time updates via webhooks

2. **Budgeting Application**
   - Category-based spending analysis (47 categories available)
   - Budget limits and alerts per category
   - Spending trends and visualizations
   - Real-time budget monitoring via webhooks

3. **Investment Tracking**
   - Savings growth monitoring
   - Investment transaction tracking via tags/categories
   - Integration with external investment platforms
   - Net worth calculations

4. **Financial Analytics**
   - Custom reports by category, tag, or date range
   - Spending insights and patterns
   - Financial goal tracking
   - Export capabilities

### Limitations to Consider

❌ **No Direct Investment Account Access**: Up API only provides bank account data  
❌ **No Budget API**: Budgeting must be built using transaction/category data  
❌ **No Transfer/Payment API**: Read-only access (no ability to initiate transfers)  
❌ **No User Profile API**: Limited to account and transaction data  
❌ **No Attachment Upload**: Attachments can only be created via mobile app  
❌ **Limited Account Types**: Only 3 types (TRANSACTIONAL, SAVER, HOME_LOAN)  
❌ **Limited Transaction Statuses**: Only 2 (HELD, SETTLED)  
❌ **Limited Transaction Filters**: Only status, since, and until filters  

---

## Next Steps

1. **Obtain Your Personal Access Token** from the Up mobile app
2. **Test API Connectivity** using the `/util/ping` endpoint
3. **Fetch Your Accounts** to understand your data structure
4. **Explore Transactions** to see the data available
5. **Fetch Categories** to understand the complete category hierarchy
6. **Set Up Webhooks** for real-time updates (if needed)
7. **Build Your Application** using the endpoints outlined above
8. **Monitor Rate Limits** using the `X-RateLimit-Remaining` header

---

**Document Version:** 2.0  
**Last Updated:** December 2025  
**Source:** [Up Bank API Documentation](https://developer.up.com.au/#welcome)  
**Category Data:** Fetched from API on December 2025


# ZaaNet Dune Dashboard Templates

> Pre-built dashboard layouts for ZaaNet protocol analytics.

---

## Dashboard 1: Protocol Overview

### Purpose
High-level protocol health and activity metrics for executive summaries.

### Key Metrics (Top Row)
| Metric | Query Source | Visualization |
|--------|--------------|---------------|
| Total Payment Volume | `01_protocol_overview.sql` | Big Number |
| Total Networks | `01_protocol_overview.sql` | Big Number |
| Total Hosts | `01_protocol_overview.sql` | Big Number |
| Active Networks (30d) | `01_protocol_overview.sql` | Big Number |

### Charts (Middle Row)
- **Daily Volume (30 Days)** - Area chart from `02_payment_volume.sql`
- **Networks Registered Over Time** - Line chart from `04_network_growth.sql`
- **Payment Volume by Day of Week** - Bar chart from `02_payment_volume.sql`

### Tables (Bottom Row)
- **Top 10 Hosts by Earnings** - From `03_host_analytics.sql`
- **Recent Emergency Events** - From `07_security_audit.sql`

### Refresh Rate
- Every 15 minutes for real-time monitoring

---

## Dashboard 2: Financial Performance

### Purpose
Track revenue, fees, and protocol economics.

### Key Metrics (Top Row)
| Metric | Query Source | Visualization |
|--------|--------------|---------------|
| Total Platform Fees | `01_protocol_overview.sql` | Big Number |
| Monthly Revenue | `05_financial_analytics.sql` | Big Number |
| Total Host Payouts | `01_protocol_overview.sql` | Big Number |
| Avg Transaction Value | `02_payment_volume.sql` | Big Number |

### Charts (Middle Row)
- **Monthly Revenue Breakdown** - Stacked area from `05_financial_analytics.sql`
- **Daily Revenue** - Area chart from `05_financial_analytics.sql`
- **Fee Percentage Trend** - Line chart from `05_financial_analytics.sql`

### Charts (Bottom Row)
- **Revenue by Network Tier** - Pie chart from `05_financial_analytics.sql`
- **Top Hosts by Earnings** - Horizontal bar from `03_host_analytics.sql`

### Refresh Rate
- Every 1 hour

---

## Dashboard 3: Network & Host Performance

### Purpose
Monitor network growth and host performance.

### Key Metrics (Top Row)
| Metric | Query Source | Visualization |
|--------|--------------|---------------|
| Total Networks | `01_protocol_overview.sql` | Big Number |
| Active Hosts | `01_protocol_overview.sql` | Big Number |
| Networks Added (30d) | `04_network_growth.sql` | Big Number |
| New Hosts (30d) | `03_host_analytics.sql` | Big Number |

### Charts (Middle Row)
- **Network Registration Trend** - Area chart from `04_network_growth.sql`
- **Network Status Changes** - Stacked bar from `04_network_growth.sql`
- **Host Network Distribution** - Histogram from `03_host_analytics.sql`

### Charts (Bottom Row)
- **Network Price Distribution** - Pie chart from `04_network_growth.sql`
- **Top 20 Hosts by Earnings** - Table from `03_host_analytics.sql`

### Refresh Rate
- Every 15 minutes

---

## Dashboard 4: Security & Governance

### Purpose
Track admin actions, emergencies, and protocol security.

### Key Metrics (Top Row)
| Metric | Query Source | Visualization |
|--------|--------------|---------------|
| Emergency Mode Count | `07_security_audit.sql` | Big Number |
| Fee Changes | `07_security_audit.sql` | Big Number |
| Treasury Changes | `07_security_audit.sql` | Big Number |
| Operator Changes | `07_security_audit.sql` | Big Number |

### Charts (Middle Row)
- **Emergency Events Timeline** - Timeline chart from `07_security_audit.sql`
- **Fee Change History** - Table from `07_security_audit.sql`
- **Pause/Unpause Events** - Timeline from `07_security_audit.sql`

### Tables (Bottom Row)
- **Recent Admin Actions** - Full table from `07_security_audit.sql`
- **All Emergency Toggles** - Table from `07_security_audit.sql`

### Refresh Rate
- Every 5 minutes (real-time monitoring)

---

## Dashboard 5: User Engagement

### Purpose
Understand user behavior and engagement patterns.

### Key Metrics (Top Row)
| Metric | Query Source | Visualization |
|--------|--------------|---------------|
| Unique Payers (30d) | `08_user_activity.sql` | Big Number |
| New Users (30d) | `08_user_activity.sql` | Big Number |
| ARPU (Monthly) | `08_user_activity.sql` | Big Number |
| Avg Transactions/User | `08_user_activity.sql` | Big Number |

### Charts (Middle Row)
- **Active Users Over Time** - Area chart from `08_user_activity.sql`
- **User Segment Distribution** - Pie chart from `08_user_activity.sql`
- **Transaction Frequency** - Bar chart from `08_user_activity.sql`

### Charts (Bottom Row)
- **Peak Usage Hours** - Heatmap from `08_user_activity.sql`
- **Top Users by LTV** - Table from `08_user_activity.sql`

### Refresh Rate
- Every 1 hour

---

## Dashboard 6: Voucher Analytics

### Purpose
Track voucher sales and usage patterns.

### Key Metrics (Top Row)
| Metric | Query Source | Visualization |
|--------|--------------|---------------|
| Total Vouchers Registered | `01_protocol_overview.sql` | Big Number |
| Vouchers (30d) | `06_voucher_analytics.sql` | Big Number |
| Registration Revenue | `06_voucher_analytics.sql` | Big Number |

### Charts (Middle Row)
- **Voucher Registrations by Tier** - Pie chart from `06_voucher_analytics.sql`
- **Voucher Registration Trend** - Area chart from `06_voucher_analytics.sql`
- **Transaction Size Distribution** - Bar chart from `06_voucher_analytics.sql`

### Tables (Bottom Row)
- **Hosts with Most Vouchers** - Table from `06_voucher_analytics.sql`
- **Voucher Cost Analysis** - Table from `06_voucher_analytics.sql`

### Refresh Rate
- Every 1 hour

---

## Implementation Notes

### Adding to Dune

1. **Create New Dashboard**
   - Go to Dune → Dashboards → New Dashboard
   - Name: "ZaaNet - [Dashboard Name]"

2. **Add Queries**
   - Copy SQL from `dune-queries/` folder
   - Create new query in Dune
   - Run to verify results

3. **Add Visualizations**
   - Click "Add Visualization" on query results
   - Select chart type from templates above
   - Configure colors and labels

4. **Arrange Layout**
   - Drag and drop to arrange
   - Set appropriate refresh rates
   - Add filters if needed

### Color Scheme Recommendation

| Element | Color |
|---------|-------|
| Primary (Protocol) | `#6366F1` (Indigo) |
| Secondary (Hosts) | `#10B981` (Emerald) |
| Accent (Payments) | `#F59E0B` (Amber) |
| Danger (Emergencies) | `#EF4444` (Red) |
| Success | `#22C55E` (Green) |

### Sharing

- Set dashboard to **Public** for grant reviewers
- Use **Embed** feature for documentation
- Create **Read-only** view for team members

---

*For support, refer to Dune documentation or contact ZaaNet team.*

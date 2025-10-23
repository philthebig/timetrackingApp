# Timekeeping Import & Analytics Tool

A comprehensive ColdFusion-based web application for importing Excel timekeeping data and automatically enriching it with organizational directorate information from a SQL database view.

## Features

- **Excel File Import**: Upload and parse Excel timekeeping reports
- **Automatic Data Enrichment**: Match clients with directorate/division/branch information from vUserInfo view
- **Interactive Dashboard**: Visualize hours by directorate, category, and client
- **Export Capabilities**: Export enriched data to Excel in various formats
- **Unmatched Client Tracking**: Identify and report clients that couldn't be matched
- **Batch Processing**: Track multiple imports with batch IDs
- **Responsive Design**: Modern Bootstrap 5 interface

## System Requirements

- **ColdFusion**: Adobe ColdFusion 2018+ or Lucee 5.3+
- **Database**: Microsoft SQL Server 2016+ with access to BRANCH_Directory.dbo.vUserInfo view
- **Web Server**: IIS, Apache, or built-in ColdFusion web server
- **Browser**: Modern browser (Chrome, Firefox, Edge, Safari)

## Installation

### 1. Database Setup

Run the SQL scripts in order:

```bash
# Connect to your SQL Server and run:
sqlcmd -S your_server -d your_database -i sql/01_create_tables.sql
sqlcmd -S your_server -d your_database -i sql/02_create_stored_procedure.sql
sqlcmd -S your_server -d your_database -i sql/03_create_views.sql
```

Or use SQL Server Management Studio to execute each script manually.

### 2. Application Deployment

1. Copy the `cfm`, `css`, `js` folders to your web root or virtual directory
2. Create required directories:
   ```
   /uploads   (for temporary file storage)
   /exports   (for generated Excel exports)
   ```
3. Set appropriate permissions on these directories for the web server

### 3. Configuration

Edit `Application.cfc` to configure:

```coldfusion
<!--- Update this line with your datasource name --->
<cfset this.datasource = "yourDatasource">
```

Update datasource references in all `.cfm` files:
- `index.cfm`
- `dashboard.cfm`
- `export.cfm`

Replace `datasource="yourDatasource"` with your actual SQL Server datasource name.

### 4. ColdFusion Datasource Setup

1. Open ColdFusion Administrator (http://localhost:8500/CFIDE/administrator/)
2. Navigate to Data & Services > Data Sources
3. Add a new datasource:
   - **Name**: yourDatasource (or your chosen name)
   - **Driver**: Microsoft SQL Server
   - **Server**: your_sql_server
   - **Port**: 1433 (default)
   - **Database**: your_database
   - **Username/Password**: (appropriate credentials)
4. Test the connection and verify access to BRANCH_Directory.dbo.vUserInfo view

## Directory Structure

```
timekeeping_app/
├── cfm/
│   ├── Application.cfc          # Application configuration
│   ├── index.cfm                # Upload page
│   ├── dashboard.cfm            # Analytics dashboard
│   └── export.cfm               # Export functionality
├── css/
│   └── styles.css               # Custom styles
├── js/
│   └── upload.js                # Client-side functionality
├── sql/
│   ├── 01_create_tables.sql     # Database tables
│   ├── 02_create_stored_procedure.sql  # Processing logic
│   └── 03_create_views.sql      # Dashboard views
├── uploads/                     # Temporary upload directory
└── exports/                     # Generated export files
```

## Usage

### Importing Data

1. Navigate to the application home page (index.cfm)
2. Click "Choose File" and select your timekeeping Excel file
3. (Optional) Enter your name in "Imported By"
4. (Optional) Add any notes about the import
5. Click "Upload and Process"
6. Wait for processing to complete
7. Review the import summary showing matched and unmatched records
8. Click "View Dashboard" to see analytics

### Excel File Format

The application expects Excel files with the following structure:
- Row 3: Headers (Row Labels, Sum of Recorded Hours)
- Data starts from row 4
- Hierarchical format:
  - Category rows (e.g., "ACO", "Charities")
  - Project/Matter rows
  - Client contact rows with email addresses

Example:
```
Row Labels                                              | Sum of Recorded Hours
ACO                                                     | 0.5
MISC - Oral Advice - LPRAB - 2022-26                  | 0.5
Halverson, Soren [Client] soren.halverson@cra-arc.gc.ca| 0.5
```

### Viewing Dashboard

1. From the upload page, click "Dashboard" in the navigation
2. View summary statistics:
   - Total Hours
   - Unique Clients
   - Total Projects
   - Number of Directorates
3. Explore visualizations:
   - Hours by Directorate (bar chart)
   - Hours by Category (pie chart)
4. Review detailed tables:
   - Top Directorates
   - Top Clients
5. Check unmatched clients (if any) to identify data issues

### Exporting Data

From the dashboard, click any export button:
- **Export by Directorate**: Full details organized by directorate
- **Export by Category**: Data grouped by service category
- **Export Client Details**: Summary of client activity
- **Export Unmatched**: Clients that couldn't be matched (if applicable)

All exports are Excel files with formatted headers and auto-sized columns.

## Database Schema

### Main Tables

**TimekeepingStaging**
- Temporary storage for uploaded data before processing

**TimekeepingEnriched**
- Final enriched data with all directorate information
- Matched clients with full organizational details

**ImportBatch**
- Tracks each import with summary statistics
- Useful for auditing and historical analysis

**UnmatchedClients**
- Records clients that couldn't be matched with vUserInfo
- Helps identify data quality issues

### Key Views

**vw_HoursByDirectorate**
- Aggregates hours, clients, and projects by directorate

**vw_HoursByCategory**
- Summarizes activity by service category

**vw_TopClientsByHours**
- Ranks clients by total hours consumed

## Matching Logic

The application matches clients using a two-step approach:

1. **Email Match** (Primary): Exact match on email address
   ```sql
   LOWER(LTRIM(RTRIM(s.ClientEmail))) = LOWER(LTRIM(RTRIM(u.userID)))
   ```

2. **Name Match** (Secondary): Match on first and last name
   ```sql
   LOWER(LTRIM(RTRIM(s.ClientFirstName))) = LOWER(LTRIM(RTRIM(u.firstName)))
   AND LOWER(LTRIM(RTRIM(s.ClientLastName))) = LOWER(LTRIM(RTRIM(u.lastName)))
   ```

Unmatched records are logged separately for review.

## Troubleshooting

### Common Issues

**Problem**: File upload fails
- **Solution**: Check that `/uploads` directory exists and has write permissions
- Verify file is valid Excel format (.xlsx or .xls)
- Ensure file size is under 10MB

**Problem**: No clients matched
- **Solution**: Verify vUserInfo view is accessible
- Check email formats in Excel file match userID in vUserInfo
- Ensure database connection is working

**Problem**: Dashboard shows no data
- **Solution**: Verify data was successfully imported (check ImportBatch table)
- Ensure stored procedure executed without errors
- Check that matched records exist in TimekeepingEnriched table

**Problem**: Charts not displaying
- **Solution**: Check browser console for JavaScript errors
- Ensure Chart.js CDN is accessible
- Verify query results are returning data

### Debug Mode

To enable debug output, add to any .cfm page:
```coldfusion
<cfsetting showDebugOutput="true">
```

### Logs

Check ColdFusion logs:
- Application: `[CF_Home]/logs/application.log`
- Custom errors: `[CF_Home]/logs/timekeeping_errors.log`

## Security Considerations

- **File Upload**: Only accepts .xlsx and .xls files, max 10MB
- **SQL Injection**: All queries use cfqueryparam for parameterization
- **XSS Protection**: Security headers configured in Application.cfc
- **Session Management**: 30-minute timeout configured
- **Authentication**: Add your organization's authentication in onRequestStart()

## Performance Optimization

For large datasets (1000+ records):
- Database indexes are created on key columns
- Batch processing handles uploads efficiently
- Consider increasing ColdFusion request timeout for very large files

## Customization

### Adding Fields

To include additional fields from vUserInfo:

1. Add columns to TimekeepingEnriched table
2. Update stored procedure to include new fields in SELECT
3. Modify dashboard queries to display new fields
4. Update export.cfm to include in exports

### Changing Match Logic

Edit stored procedure `sp_EnrichTimekeepingData`:
```sql
-- Modify the JOIN condition in the main INSERT statement
LEFT JOIN [BRANCH_Directory].[dbo].[vUserInfo] u 
    ON [your custom matching logic]
```

### Adding Visualizations

Edit `dashboard.cfm`:
```javascript
// Add new Chart.js chart
const newChart = new Chart(ctx, {
    type: 'line', // or 'bar', 'doughnut', etc.
    data: yourData,
    options: yourOptions
});
```

## Support

For issues or questions:
1. Check this README
2. Review database logs and error messages
3. Verify SQL scripts executed successfully
4. Ensure all prerequisites are met

## Version History

- **v1.0.0** (2024) - Initial release
  - Excel import functionality
  - Automatic data enrichment
  - Interactive dashboard
  - Export capabilities

## License

Internal use only. Modify as needed for your organization.

## Credits

Built with:
- ColdFusion
- Bootstrap 5
- Chart.js
- Font Awesome
- Microsoft SQL Server

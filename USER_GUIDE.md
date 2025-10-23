# User Guide - Timekeeping Import & Analytics Tool

## Table of Contents
1. [Getting Started](#getting-started)
2. [Importing Data](#importing-data)
3. [Understanding Results](#understanding-results)
4. [Using the Dashboard](#using-the-dashboard)
5. [Exporting Data](#exporting-data)
6. [Troubleshooting](#troubleshooting)
7. [FAQ](#faq)

---

## Getting Started

### Accessing the Application

1. Open your web browser (Chrome, Firefox, Edge, or Safari recommended)
2. Navigate to: `http://your-server/timekeeping/`
3. You should see the home page with the upload form

### System Requirements

- **Browser**: Modern web browser with JavaScript enabled
- **File Format**: Excel files (.xlsx or .xls)
- **Maximum File Size**: 10 MB
- **Internet Connection**: Required for chart displays

---

## Importing Data

### Step 1: Prepare Your Excel File

Your timekeeping report should be in the standard format:
- Row 3 contains headers: "Row Labels" and "Sum of Recorded Hours"
- Data begins at row 4
- Contains client email addresses or full names

**Example Format:**
```
Row Labels                                              | Sum of Recorded Hours
Charities                                              | 816.8
Project - Matter Name - Date                           | 7.5
Smith, John [Client Contact] john.smith@cra-arc.gc.ca | 7.5
```

### Step 2: Upload the File

1. Click the **"Choose File"** button
2. Select your Excel file from your computer
3. (Optional) Enter your name in the "Imported By" field
4. (Optional) Add any notes about this import
5. Click **"Upload and Process"**

### Step 3: Wait for Processing

- A loading indicator will appear
- Processing typically takes 10-30 seconds depending on file size
- **Do not close the browser** while processing

### Step 4: Review Results

After processing, you'll see a summary showing:
- **Batch ID**: Unique identifier for this import
- **Total Records**: Number of client entries processed
- **Matched Records**: Clients successfully linked to directory
- **Unmatched Records**: Clients that couldn't be matched
- **Match Rate**: Percentage of successful matches

---

## Understanding Results

### Match Rate

The match rate indicates how many clients were successfully matched with the directory:

- **90-100%** (Green): Excellent - Most clients identified
- **70-89%** (Yellow): Good - Some manual review needed
- **Below 70%** (Red): Poor - Check data quality

### Why Clients Don't Match

Common reasons for unmatched clients:
1. **Email mismatch**: Email in file doesn't match directory
2. **Name spelling differences**: First or last name doesn't match exactly
3. **Inactive users**: Person no longer in active directory
4. **External clients**: People outside the organization

### What Happens to Unmatched Clients

- Logged in a separate table for review
- Available in exports
- Does not prevent successful processing
- Can be manually reviewed and corrected

---

## Using the Dashboard

### Overview Section

At the top of the dashboard, you'll find four summary cards:

1. **Total Hours**: Sum of all recorded hours
2. **Unique Clients**: Number of different clients
3. **Total Projects**: Number of project/matters
4. **Directorates**: Number of organizational units involved

### Charts

#### Hours by Directorate (Bar Chart)
- Shows top 10 directorates by hours consumed
- **How to read**: Taller bars = more hours
- **Use**: Identify which directorates use most resources

#### Hours by Category (Pie Chart)
- Breaks down hours by service category
- **How to read**: Larger slices = more hours
- **Use**: See distribution of work types

### Tables

#### Top Directorates Table
Shows detailed breakdown:
- **Directorate**: Organization unit name and acronym
- **Clients**: Number of unique clients
- **Projects**: Total number of projects
- **Hours**: Total hours consumed

#### Top Clients Table
Lists most active clients:
- **Client**: Name and email
- **Directorate**: Their organizational unit
- **Projects**: Number of projects they're involved in
- **Hours**: Total hours for this client

### Unmatched Clients Section

If any clients couldn't be matched, you'll see a red alert box with:
- Email address
- First and last name
- Full contact information
- Hours assigned to that client

**Action**: Review these entries and verify email addresses or contact directory admin.

---

## Exporting Data

### Export Options

Click any export button to download Excel files:

#### 1. Export by Directorate
**Contents**: Full dataset organized by organizational structure
**Includes**:
- Directorate, Division, Branch information (English and French)
- Project/matter details
- Client information
- Hours and import dates

**Use**: Executive reporting, organizational analysis

#### 2. Export by Category
**Contents**: Data grouped by service type
**Includes**:
- Service category
- Project details
- Client information
- Organizational affiliation
- Hours

**Use**: Service-specific analysis, workload planning

#### 3. Export Client Details
**Contents**: Client-focused summary
**Includes**:
- Client contact information
- Organizational affiliation
- Number of projects
- Total and average hours
- Date range of activity

**Use**: Client relationship management, capacity planning

#### 4. Export Unmatched (if applicable)
**Contents**: Clients that couldn't be matched
**Includes**:
- Email address
- Name information
- Full contact details
- Hours

**Use**: Data quality review, manual corrections

### Working with Exports

1. **Opening**: Double-click downloaded file or open with Excel
2. **Filtering**: Use Excel's built-in filter (Data > Filter)
3. **Sorting**: Click column headers to sort
4. **Formatting**: All exports include formatted headers
5. **Saving**: Save a copy before making changes

---

## Troubleshooting

### Upload Issues

**Problem**: "File upload failed"
- **Check**: File is .xlsx or .xls format
- **Check**: File size is under 10 MB
- **Try**: Compress file or split into multiple files

**Problem**: "Invalid file format"
- **Check**: File is not corrupted
- **Try**: Open in Excel and save as new file
- **Try**: Remove any special formatting or macros

### Processing Issues

**Problem**: Processing takes too long (over 2 minutes)
- **Reason**: Large file or server load
- **Action**: Wait patiently, do not refresh
- **If stuck**: Contact IT support with batch ID

**Problem**: "Processing failed" error
- **Check**: Excel file structure matches expected format
- **Try**: Upload a smaller test file first
- **Action**: Note the error message and contact support

### Display Issues

**Problem**: Charts not showing
- **Check**: JavaScript is enabled in browser
- **Try**: Refresh page (F5)
- **Try**: Different browser
- **Check**: Internet connection (charts use online library)

**Problem**: Data looks incorrect
- **Action**: Note which data looks wrong
- **Action**: Check source Excel file
- **Action**: Contact support with batch ID

---

## FAQ

### General Questions

**Q: How often should I import data?**
A: Import data as often as your reporting cycle requires - weekly, monthly, or quarterly.

**Q: Can I delete old imports?**
A: Yes, contact your administrator. Imports are tracked by batch ID.

**Q: Is my data secure?**
A: Yes, data is stored in a secure database. Access is controlled by your IT team.

**Q: Can I import multiple files at once?**
A: No, process one file at a time. You can import multiple files sequentially.

### Technical Questions

**Q: What email format is required?**
A: Standard format: firstname.lastname@domain.com. Must match directory exactly.

**Q: Why are some names not matching?**
A: Names must match exactly (case-insensitive). Check for:
- Middle initials
- Hyphenated names
- Accent marks
- Nicknames vs. formal names

**Q: Can I edit data after import?**
A: No direct editing. For corrections, prepare corrected Excel file and re-import.

**Q: How long is data retained?**
A: Contact your administrator for retention policies.

### Dashboard Questions

**Q: What period does the dashboard cover?**
A: By default, all imported data. Use batch ID filter for specific imports.

**Q: Can I see historical comparisons?**
A: Yes, import data from different periods and compare batch IDs.

**Q: Can I print the dashboard?**
A: Yes, use browser print function (Ctrl+P or Cmd+P).

**Q: Can I share dashboard views?**
A: Export data to Excel and share files. Or share your screen during meetings.

### Export Questions

**Q: What format are exports?**
A: Excel (.xlsx) with formatted headers and auto-sized columns.

**Q: Can I customize exports?**
A: Not directly. Export and then filter/format in Excel as needed.

**Q: Do exports include unmatched clients?**
A: Only if you specifically click "Export Unmatched" button.

**Q: Can I schedule automatic exports?**
A: Not currently. Contact IT if this feature is needed.

---

## Best Practices

### Data Quality

1. **Verify email addresses** before importing
2. **Use standard formats** for consistency
3. **Clean data** in Excel before upload (remove extra spaces, fix typos)
4. **Test with small file** first if unsure
5. **Review unmatched clients** immediately after import

### Organization

1. **Add notes** to each import for context
2. **Use consistent naming** for files
3. **Export summaries** for your records
4. **Track batch IDs** for important imports
5. **Archive source files** in your own folders

### Efficiency

1. **Batch similar imports** together
2. **Schedule imports** during low-usage times
3. **Prepare exports** before meetings
4. **Use filters** in Excel for specific analysis
5. **Bookmark** the application URL

---

## Getting Help

### Quick Help
- **Hover** over elements for tooltips
- **Check** this user guide
- **Review** error messages carefully

### Technical Support
- **Email**: [support email]
- **Phone**: [support phone]
- **Include**: Batch ID, screenshot, error message

### Training
- **Request**: Additional training sessions
- **Schedule**: Demos for new users
- **Resources**: Additional documentation

---

## Keyboard Shortcuts

- **Ctrl/Cmd + R**: Refresh page
- **Ctrl/Cmd + P**: Print view
- **Ctrl/Cmd + F**: Find on page
- **Esc**: Cancel file selection dialog

---

## Glossary

**Batch**: A single import session with unique ID
**Directorate**: Top-level organizational unit
**Division**: Mid-level organizational unit within directorate
**Branch**: Lower-level organizational unit within division
**Match Rate**: Percentage of clients successfully linked to directory
**Enriched Data**: Data combined with organizational information
**Staging**: Temporary storage during processing

---

**Need more help?** Contact your system administrator or IT support team.

**Version**: 1.0 | **Last Updated**: [Date]

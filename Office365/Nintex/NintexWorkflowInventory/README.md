# Introduction

This is a PowerShell-Script to inventory an Office365 tenant; where is Nintex Workflow for Office365 enabled (lists all webs in a csv-file called `sites.csv`). Also a list with all workflows, that have been created using Nintex Workflow will be created (in a file `wfs.csv`). This list contains (among others), a hyperlink to the corresponding workflow-gallery.

To find out more, read the following blog-posts series:
- [Migrate your tenant to another data-center (1 of 3)](https://community.nintex.com/community/build-your-own/nintex-for-office-365/blog/2017/02/20/migrate-your-tenant-to-another-datacenter-1-of-3)
- [Migrate your tenant to another data-center (2 of 3) - or where is the workflow app?](https://community.nintex.com/community/build-your-own/nintex-for-office-365/blog/2017/02/22/migrate-your-tenant-to-another-datacenter-2-of-3-or-where-is-the-workflow-app)
- [Migrate your tenant to another data-center (3 of 3) - where are all the workflows?](https://community.nintex.com/community/build-your-own/nintex-for-office-365/blog/2017/04/20/migrate-your-tenant-to-another-datacenter-3-of-3-where-are-all-the-workflows)


# Prerequisits:

- [https://github.com/SharePoint/PnP-PowerShell](https://github.com/SharePoint/PnP-PowerShell)
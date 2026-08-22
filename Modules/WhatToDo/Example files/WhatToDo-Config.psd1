@{
    TaskListFile = 'path\to\WhatToDo\tasks.todo'
    BackupTaskListFileOncePerDayOnStartup = $false
    UsePSCalendarModule = $false
    CalendarFutureDaysToShow = 7
    NumberOfRecurringTaskDaysToAddBeforehand = 14

    RecurringTasks = @(
        <#@{
            DueDate = @{
                Month = 1, 2, 3, 9
                # Day = 18, 25, 27, 30
                # Week = 1, 3, 5, 7, 37
                # Weekday = 'Tuesday', 'Thursday'
                # FirstWeekdayOfMonth = 'Tuesday'
                # SecondWeekdayOfMonth = 'Thursday', 'Friday'
                # ThirdWeekdayOfMonth = 'Tuesday'
                # FourthWeekdayOfMonth = 'Tuesday'
            }
            
            Task = @{
                Priority = 'R'
                EstimateMinutes = 90
                Description = 'Test 1'
            }
        }#>
    )
}
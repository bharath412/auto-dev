*** Settings ***
Library    RequestsLibrary
Library    SeleniumLibrary
Library    Collections
Library    FakerLibrary

Suite Setup       Setup Test Suite
Suite Teardown    Close All Browsers

*** Variables ***
${BASE_URL}         http://localhost:8000
${FRONTEND_URL}     http://localhost:8080
${BROWSER}          edge

# API Endpoints
${EMPLOYEES_ENDPOINT}    ${BASE_URL}/employees

# Web Elements
${ADD_EMPLOYEE_BTN}     css:button[onclick='showAddModal()']
${NAME_INPUT}           id:name
${DEPARTMENT_INPUT}     id:department
${POSITION_INPUT}       id:position
${SAVE_BTN}            css:button[onclick='saveEmployee()']
${SEARCH_INPUT}        id:searchInput

*** Keywords ***
Setup Test Suite
    Create Session    employee_api    ${BASE_URL}    verify=True
    Open Browser    ${FRONTEND_URL}    ${BROWSER}
    Maximize Browser Window

Generate Random Employee Data
    ${name}=         FakerLibrary.Name
    ${department}=   FakerLibrary.Job
    ${position}=     FakerLibrary.Job
    &{employee}=     Create Dictionary    
    ...    name=${name}    
    ...    department=${department}    
    ...    position=${position}
    RETURN    &{employee}

# API Keywords
Create Employee Via API
    [Arguments]    ${employee_data}
    ${response}=    POST On Session    
    ...    employee_api    
    ...    /employees/    
    ...    json=${employee_data}
    Status Should Be    201    ${response}
    RETURN    ${response.json()}

Get All Employees Via API
    ${response}=    GET On Session    employee_api    /employees/
    Status Should Be    200    ${response}
    RETURN    ${response.json()}

Update Employee Via API
    [Arguments]    ${employee_id}    ${employee_data}
    ${response}=    PUT On Session    
    ...    employee_api    
    ...    /employees/${employee_id}    
    ...    json=${employee_data}
    Status Should Be    200    ${response}
    RETURN    ${response.json()}

Delete Employee Via API
    [Arguments]    ${employee_id}
    ${response}=    DELETE On Session    
    ...    employee_api    
    ...    /employees/${employee_id}
    Status Should Be    200    ${response}

Get Employee Via API
    [Arguments]    ${employee_id}
    ${response}=    GET On Session    
    ...    employee_api    
    ...    /employees/${employee_id}
    ...    expected_status=404

# UI Keywords
Create Employee Via UI
    [Arguments]    ${employee_data}
    Click Element    ${ADD_EMPLOYEE_BTN}
    Wait Until Element Is Visible    ${NAME_INPUT}
    Input Text    ${NAME_INPUT}        ${employee_data}[name]
    Input Text    ${DEPARTMENT_INPUT}  ${employee_data}[department]
    Input Text    ${POSITION_INPUT}    ${employee_data}[position]
    Click Element    ${SAVE_BTN}
    Wait Until Page Contains    ${employee_data}[name]

Search Employee
    [Arguments]    ${search_term}
    Input Text    ${SEARCH_INPUT}    ${search_term}
    Sleep    1s    # Wait for search to filter

Verify Employee Exists
    [Arguments]    ${employee_name}
    Page Should Contain    ${employee_name}

Verify Employee Does Not Exist
    [Arguments]    ${employee_name}
    Page Should Not Contain    ${employee_name}

Select Multiple Employees
    [Arguments]    @{employee_ids}
    FOR    ${id}    IN    @{employee_ids}
        ${checkbox_locator}=    Set Variable    id:check-${id}
        Wait Until Element Is Visible    ${checkbox_locator}
        Scroll Element Into View    ${checkbox_locator}
        Sleep    0.5s    # Add a small delay before clicking
        Click Element    ${checkbox_locator}
    END
    Wait Until Element Is Enabled    id:deleteSelectedBtn

Delete Selected Employees
    ${delete_button}=    Set Variable    id:deleteSelectedBtn
    Wait Until Element Is Visible    ${delete_button}
    Scroll Element Into View    ${delete_button}
    Wait Until Element Is Enabled    ${delete_button}
    Click Element    ${delete_button}
    # Handle confirmation alert
    Handle Alert    ACCEPT
    # Wait for the operation to complete
    Sleep    2s
    # Wait for employees to be removed (table refresh)
    Wait Until Page Contains Element    id:employeeContainer

Verify Page Title
    ${title}=    Get Title
    Should Be Equal    ${title}    Employee System
    Element Text Should Be    css:.navbar-brand    Employee System

*** Test Cases ***
Create New Employee Via API
    ${employee_data}=    Generate Random Employee Data
    ${response}=    Create Employee Via API    ${employee_data}
    # Convert response to string before checking
    ${id_str}=    Convert To String    ${response}[id]
    Should Not Be Empty    ${id_str}
    Should Be Equal As Strings    ${response}[name]        ${employee_data}[name]
    Should Be Equal As Strings    ${response}[department]  ${employee_data}[department]
    Should Be Equal As Strings    ${response}[position]    ${employee_data}[position]

Create New Employee Via UI
    ${employee_data}=    Generate Random Employee Data
    Create Employee Via UI    ${employee_data}
    Verify Employee Exists    ${employee_data}[name]

Search Employee
    ${employee_data}=    Generate Random Employee Data
    Create Employee Via UI    ${employee_data}
    Search Employee    ${employee_data}[name]
    Verify Employee Exists    ${employee_data}[name]

Update Employee
    ${employee_data}=    Generate Random Employee Data
    ${response}=    Create Employee Via API    ${employee_data}
    ${employee_id}=    Set Variable    ${response}[id]
    
    ${updated_data}=    Generate Random Employee Data
    ${update_response}=    Update Employee Via API    ${employee_id}    ${updated_data}
    Should Be Equal    ${update_response}[name]    ${updated_data}[name]

Delete Employee
    ${employee_data}=    Generate Random Employee Data
    ${response}=    Create Employee Via API    ${employee_data}
    ${employee_id}=    Set Variable    ${response}[id]
    
    Delete Employee Via API    ${employee_id}
    Reload Page
    Verify Employee Does Not Exist    ${employee_data}[name]

Delete Multiple Employees
    # Create multiple test employees
    ${employee_data1}=    Generate Random Employee Data
    ${response1}=    Create Employee Via API    ${employee_data1}
    ${employee_id1}=    Set Variable    ${response1}[id]
    
    ${employee_data2}=    Generate Random Employee Data
    ${response2}=    Create Employee Via API    ${employee_data2}
    ${employee_id2}=    Set Variable    ${response2}[id]
    
    # Make sure the page is loaded fresh
    Go To    ${FRONTEND_URL}
    Wait Until Element Is Visible    id:employeeContainer
    Sleep    2s    # Give the page more time to fully load
    
    # Select and delete both employees
    Select Multiple Employees    ${employee_id1}    ${employee_id2}
    Delete Selected Employees
    
    # Verify both employees are gone from UI
    Verify Employee Does Not Exist    ${employee_data1}[name]
    Verify Employee Does Not Exist    ${employee_data2}[name]
    
    # Also verify via API that they're gone
    Run Keyword And Ignore Error    Get Employee Via API    ${employee_id1}
    Run Keyword And Ignore Error    Get Employee Via API    ${employee_id2}

Verify Page Titles
    Go To    ${FRONTEND_URL}
    Wait Until Element Is Visible    css:.navbar-brand
    Verify Page Title
# Terminology

<table>
    <thead>
        <tr>
            <th>Term</th>
            <th>Description</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td><em>terminal&nbsp;window</em></td>
            <td>
                This is the window that is by default opened in a horizontal split to
                show the build terminal and output.
            </td>
        </tr>
        <tr>
            <td><em>view window</em></td>
            <td>
                The <em>view window</em> is used to open files during navigation.
                It is set to the current window, whenever a navigation action
                is triggered, except when the cursor is in the <em>terminal window</em>.
            </td>
        </tr>
        <tr>
            <td><em>match group</em></td>
            <td>
                This is a set of <em>matchers</em> for a common context, such as a programming
                language or a build tool. Match groups can be switched as needed.
            </td>
        </tr>
        <tr>
            <td><em>matcher</em></td>
            <td>
                A <em>matcher</em> matches one or multiple lines of terminal output. Data
                from the output is captured and stored in a <em>match item</em>.
            </td>
        </tr>
        <tr>
            <td><em>match item</em></td>
            <td>
                The <em>match item</em> represents one or multiple lines of output that were
                recognized by a matcher. It stores information about the match itself, as
                well as additional information provided by the matcher, such as the error
                message, the line number, the file etc.
            </td>
        </tr>
        <tr>
            <td><em>source location</em></td>
            <td>
                The <em>source location</em> is the location of the match item in the output
                of the terminal (ie. the location of the message itself).
            </td>
        </tr>
        <tr>
            <td><em>target location</em></td>
            <td>
                The <em>target location</em> is the location indicated in the message of the
                <em>match item</em>. It has to be produced by the <em>matcher</em>. This is
                typically the location of an error that triggered the error message.
            </td>
        </tr>
        <tr>
            <td><em>match type</em></td>
            <td>
                The type of a <em>match item</em>. Such as <code>error</code>, <code>warning</code>,
                <code>info</code>, etc.
            </td>
        </tr>
        <tr>
            <td><em>builder</em></td>
            <td>
                A <em>builder</em> is used to trigger a build command or build tool in the
                terminal, when certain conditions defined by the build trigger are detected.
            </td>
        </tr>
    </tbody>
</table>


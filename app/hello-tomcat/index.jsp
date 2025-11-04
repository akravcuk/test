<%@ page import="javax.naming.*" %>
<%
Context env = (Context) new InitialContext().lookup("java:comp/env");
Boolean maintenance = (Boolean) env.lookup("maintenance");

if (Boolean.TRUE.equals(maintenance)) {
    response.setStatus(503);
    response.setHeader("X-Maintenance","on");
%>

	<!doctype html><meta charset="utf-8">
	<title>Service Unavailable</title>
	<h1>503 Service Unavailable</h1>
	<p>The application is temporarily unavailable. Please try again later.</p>
<%
} else {
%>

	<!doctype html><meta charset="utf-8">
	<title>OK</title>
	<h1>It works (Tomcat)</h1>
<%
}
%>

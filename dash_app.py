import dash
import dash_html_components as html
import dash_core_components as dcc
from dash.dependencies import Input, Output, State
import dash_table_experiments as dt
import datetime
import os
import pandas as pd
import io
import base64
from plotly import graph_objs as go
os.chdir('F:\\Learning\\Python Stuff\\\Plotly_Dash\\App_01')

'''
A multi tab app
Tab1 -
Allow for multiple file upload of type doc,docx and pdf
use Apache tika to read the pdf
Create and render a html table
Columns : File Name, Match Flag ( a tick box), Input box
Save input box to a db in sqlite
Allow download of the file with a link

Tab2 -
Use plotly to vizualize data
# Use two dropdowns to select a x and y , if
# Show multiple graphs in a grid
'''
# Initialize the application
app = dash.Dash()
app.config['suppress_callback_exceptions']=True
# Add the banner
banner_portion = html.Div(html.H2([html.Img(src = "static/wellslogo.png"
                                                  , className="ui image")
                                , html.Div("Dash Application", className="content")]
                               , className = "ui red header")
                     , className="ui basic segment")

# Dash Explaination
dash_explain = html.Div([html.Div("Dash offers a lot of amazing possibilities to build and deploy   models"
                         , className="ui header")
                        , html.Div([html.Div([html.Img(src="static/python.jpg"
                                                     , className="ui avatar image")
                                            , html.Div("Full pythonic force", className = "content")]
                                           , className="item")
                                   , html.Div([html.Img(src="static/sklearn.png"
                                                     , className="ui avatar image")
                                              , html.Div("Build sklearn models", className = "content")]
                                             , className="item")
                                   , html.Div([html.Img(src="static/spark.png"
                                                        , className="ui avatar image")
                                               , html.Div("Connect to spark api", className = "content")]
                                              , className="item")]
                                , className="ui middle aligned selection list")]
                        , className="ui basic segment")
# Style the tabs
tab_style = {
    'border': 'none',
    'backgroundColor': 'white',
    'padding':'6px'
}

tab_selected_style = {
    'borderTop': '2px solid red',
    'borderBottom': 'none',
    'borderLeft': 'none',
    'borderRight': 'none',
    'backgroundColor': 'white',
    'padding': '6px',
    'color':'red'
}


# Add the tabs
tab_addition = html.Div([dcc.Tabs(id = "tabs", value = "tab_1"
                                  , children=[dcc.Tab(label = "Data Analysis & Viz"
                                                      , value="tab_1"
                                                      , style=tab_style
                                                      , selected_style=tab_selected_style)
                                              , dcc.Tab(label = "PDF Text Extraction"
                                                        , value = "tab_2"
                                                        , style=tab_style
                                                        , selected_style=tab_selected_style)]
                                  , style = {'height':'40px', 'width':'50%'})
                         , html.Br()
                         , html.Div(id = "tab_content", className="ui red segment")]
                        , className = "ui basic segment")

# Add a file uploader
upload_component = dcc.Upload(id='upload_data'
                               , children=html.Div(['Drag and Drop or '
                                                    ,html.A('Select Files')])
                               , style={'height': '100%',
                                        'borderWidth': '1px',
                                        'borderStyle': 'dashed',
                                        'borderRadius': '5px',
                                        'textAlign': 'center', 'padding':'7px'},
                        multiple=False)
# Add a dropdown for separator
sep_dropdown = dcc.Dropdown(options=[{'label': 'Comma ( , )', 'value': ','},
                                     {'label': 'Pipe ( | )', 'value': '|'},
                                     {'label': r'Tab ( \t )', 'value': r'\t'}]
                            , id='field_sep'
                            , style={'width':'100%', 'height':'100%'}
                            , placeholder="Select Field Separator")
# Submit File
file_submit = html.Button(id = "file_submit"
                          , n_clicks = 0
                          , children="Submit"
                          , className="ui primary button")
# Pleaseholder for a y variable

# Placeholder for x variable
# Select Chart type
# x sring, y string : Count bar chart multiple
# x string y numeric : Average bar Chart
# x numeric y numeric : scatter Chart
# x numeric y string : horizontal bar chart
dtt_place = html.Div(dt.DataTable(rows=[{}]), style={'display': 'none'})
# Final Layout
app.layout = html.Div( [banner_portion, dash_explain, dtt_place, html.Div(className="ui divider"), tab_addition]
                      , className="ui raised segment")



# Define the callback for tabs
@app.callback(Output('tab_content', 'children'), [Input('tabs', 'value')])
def tab_contents(tab):
    if tab=='tab_1':
        return [html.Div([html.Div(upload_component, className="ui six wide column")
                         , html.Div(sep_dropdown, className="ui four wide column")
                         , html.Div(file_submit, className="ui two wide column")]
                       , className="ui grid")
                , html.Div(id = 'filename', className="ui basic segment", style = {'padding-bottom':'10px'})]
    elif tab=='tab_2':
        return "We have got tab2"

# Call back to get the filename and date modified, get the data dictionary as well
@app.callback(Output('filename', 'children')
              ,[Input('file_submit', 'n_clicks')]
              ,[State('upload_data', 'filename')
                , State('upload_data', 'last_modified')
                , State('field_sep', 'value')
                , State('upload_data', 'contents')])
def update_details(n_clicks, filename, date_modified, field_sep, contents):
    try:
        last_modified = datetime.date.fromtimestamp(date_modified)
    except Exception:
        last_modified = None
    if contents and field_sep:
        content_type, content_string = contents.split(field_sep)
        decoded = base64.b64decode(content_string)
        dff = pd.read_csv(io.StringIO(decoded.decode('utf-8')), sep=field_sep, header=0, quotechar="'")
        file_summary = "The uploaded file is : {}, and it was last modified on : {}, Separator choosen is {}"\
                        .format(filename, last_modified, field_sep)
        # Add a var 1 dropdown
        drop_x = html.Div(dcc.Dropdown(id='xaxis',options=[{'label': i.title(), 'value': i} for i in dff.columns]
                                      ,value=dff.columns[0])
                          , className="ui sixteen wide column")
        # drop_y = html.Div(dcc.Dropdown(id='yaxis',options=[{'label': i.title(), 'value': i} for i in dff.columns]
        #                               ,value=dff.columns[0])
        #                       , className="ui eight wide column")

        return [html.Div(file_summary, className = "content", style = {'color':'red'})
                , html.Br()
                , html.Div(str(dff.shape), className = "content", style = {'color':'blue'})
                , html.Br()
                , html.Div([drop_x], className="ui grid")
                , html.Div(id="scatter", className="ui basic segment")]

        # return [html.Div(file_summary, className = "content", style = {'color':'red'})
        #         , html.Div(str(dff.shape), className = "content", style = {'color':'blue'})
        #         , dt.DataTable(rows=dff.to_dict('records'), columns=dff.columns, max_rows_in_viewport = 5, filterable= True)]

@app.callback(Output('scatter', 'children'), [Input('xaxis', 'value')])
def update_plot(xaxis):
    fig_obj = {'data': [go.Bar(x=dff[xaxis],mode='markers')],
                'layout': go.Layout(xaxis={'title': xaxis.title()},
                            yaxis={'title': yaxis.title()},
                            margin={'l': 40, 'b': 40, 't': 10, 'r': 0},
                            hovermode='closest')}
    # dcc.Graph(id = "scatter")
    return str(xaxis)



if __name__ == '__main__':
    app.run_server(debug=True)
